#!/bin/bash
set -e

echo "==> Touch ID sudo + shared session + no timeout"

sudo sh -c '
echo "auth       sufficient     pam_tid.so" > /etc/pam.d/sudo_local
printf "Defaults timestamp_timeout=-1\nDefaults !tty_tickets\n" > /etc/sudoers.d/timeout
chmod 440 /etc/sudoers.d/timeout
'

sudo -v

echo "done: Touch ID sudo, shared across all terminals, no timeout until logout"
