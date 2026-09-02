"""Shared filesystem-safety helpers for the Omarchy Theme Store plugin.

Every path this plugin writes to under the user's HOME is reached by
walking one path component at a time from a directory file descriptor this
process already holds and has verified (a real directory, owned by the
current user, private mode) -- never by re-opening a pathname string after
a separate check. A check-then-open-by-path is never actually safe against
something else on the box swapping a component in between the two calls,
no matter how small the gap looks; holding the descriptor and doing every
subsequent operation relative to it (openat/mkdirat/fstatat/renameat, via
Python's dir_fd parameter) closes that window instead of narrowing it.
"""

import errno
import fcntl
import json
import os
import re
import secrets
import stat as stat_module

PRIVATE_MODE = 0o700


class VerifiedDir:
    """A directory opened via a held, no-follow file descriptor."""

    def __init__(self, fd):
        self.fd = fd

    def close(self):
        os.close(self.fd)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    @classmethod
    def root(cls, path):
        """Opens a known-safe root directory (the user's own HOME) by its
        full path. This is the one place a plain path is trusted, because
        it names a directory the OS hands us directly, not one reached by
        walking through attacker-influenced components."""
        fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
        self = cls(fd)
        self._verify()
        return self

    def _verify(self):
        st = os.fstat(self.fd)
        if not stat_module.S_ISDIR(st.st_mode):
            raise RuntimeError("refusing to use a non-directory as a cache root")
        if st.st_uid != os.getuid():
            raise RuntimeError("refusing to use a directory not owned by the current user")
        if st.st_mode & (stat_module.S_IRWXG | stat_module.S_IRWXO):
            # Tighten in place rather than refuse: a pre-existing directory
            # from an older, less careful version of this plugin (or an
            # inherited umask) shouldn't become a hard failure, but it also
            # shouldn't stay group/other-accessible once we notice.
            os.fchmod(self.fd, PRIVATE_MODE)

    def component(self, name):
        """Opens (creating if needed) a single private subdirectory
        relative to this fd, refusing to follow a symlink at that step."""
        flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
        try:
            fd = os.open(name, flags, dir_fd=self.fd)
        except FileNotFoundError:
            try:
                os.mkdir(name, PRIVATE_MODE, dir_fd=self.fd)
            except FileExistsError:
                pass
            fd = os.open(name, flags, dir_fd=self.fd)
        except OSError as exc:
            # A symlinked component with O_NOFOLLOW|O_DIRECTORY fails as
            # ELOOP if it points at a non-directory, but as ENOTDIR if it
            # points at a directory -- the kernel treats the un-followed
            # symlink itself as "not a directory" either way. Both mean
            # the same thing here: refuse it.
            if exc.errno in (errno.ELOOP, errno.ENOTDIR):
                raise RuntimeError(f"refusing to use non-directory/symlinked path component: {name}")
            raise
        child = VerifiedDir(fd)
        child._verify()
        return child

    def stat_leaf(self, name):
        """lstat (no-follow) a leaf relative to this fd, or None if it
        doesn't exist."""
        try:
            return os.stat(name, dir_fd=self.fd, follow_symlinks=False)
        except FileNotFoundError:
            return None

    def read_leaf(self, name, max_bytes):
        """Bounded, no-follow, non-blocking-open read of a regular leaf
        file we own. Returns None if the leaf is missing, isn't a regular
        file, isn't ours, or exceeds max_bytes -- never raises for any of
        those, since they're all just "not safe to trust", not a program
        error. O_NONBLOCK on the open is what keeps a leaf swapped for a
        FIFO from hanging this process forever; it has no effect on the
        read itself once fstat has confirmed a regular file."""
        flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
        try:
            fd = os.open(name, flags, dir_fd=self.fd)
        except FileNotFoundError:
            return None
        except OSError as exc:
            if exc.errno in (errno.ELOOP, errno.ENXIO):
                return None
            raise
        try:
            st = os.fstat(fd)
            if not stat_module.S_ISREG(st.st_mode):
                return None
            if st.st_uid != os.getuid():
                return None
            if st.st_size > max_bytes:
                return None
            with os.fdopen(fd, "rb") as f:
                fd = None
                data = f.read(max_bytes + 1)
        finally:
            if fd is not None:
                os.close(fd)
        if len(data) > max_bytes:
            return None
        return data

    def write_leaf_atomic(self, name, data, mode=0o600):
        """Writes data to an unpredictable, exclusively-created leaf and
        atomically renames it into place, both relative to this fd."""
        tmp_name = f".tmp-{os.getpid()}-{secrets.token_hex(8)}"
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
        fd = os.open(tmp_name, flags, mode, dir_fd=self.fd)
        try:
            with os.fdopen(fd, "wb") as f:
                fd = None
                f.write(data)
            os.rename(tmp_name, name, src_dir_fd=self.fd, dst_dir_fd=self.fd)
        except BaseException:
            try:
                os.unlink(tmp_name, dir_fd=self.fd)
            except OSError:
                pass
            raise

    def unlink_leaf(self, name):
        try:
            os.unlink(name, dir_fd=self.fd)
        except FileNotFoundError:
            pass

    def total_regular_bytes(self):
        """Sum of regular-file sizes directly in this directory, via
        no-follow lstat on each entry -- a cache budget, not a du."""
        total = 0
        for entry_name in os.listdir(self.fd):
            st = self.stat_leaf(entry_name)
            if st is not None and stat_module.S_ISREG(st.st_mode):
                total += st.st_size
        return total

    def lock(self, name=".lock"):
        """Opens/creates a lock leaf relative to this fd and takes an
        exclusive advisory lock on it, held until the returned fd is
        closed. Serializes concurrent transactions against this
        directory (e.g. two plugin actions racing to edit the same
        cache or menu-extensions file)."""
        flags = os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW
        fd = os.open(name, flags, 0o600, dir_fd=self.fd)
        fcntl.flock(fd, fcntl.LOCK_EX)
        return fd


def home_dir():
    return VerifiedDir.root(os.path.expanduser("~"))


# ---- JSONC (full-line comments + trailing commas) --------------------

def strip_jsonc(text):
    # Only full-line comments (after optional leading whitespace) are
    # stripped -- never a blind "//" strip, which would mangle a
    # "https://" URL sitting inside a string value.
    text = re.sub(r"(?m)^[ \t]*//.*$", "", text)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return text


def parse_jsonc(text):
    return json.loads(strip_jsonc(text))


def is_valid_jsonc(text):
    try:
        parse_jsonc(text)
        return True
    except (ValueError, TypeError):
        return False
