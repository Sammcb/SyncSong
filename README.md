To enable universal links on Mac, enable developer mode:
swcutil developer-mode -e true

Open activity monitor and search for swcd and kill the process.
It should start again when the app runs.

To disable:
swcutil developer-mode -e false

Kill swcd again.
