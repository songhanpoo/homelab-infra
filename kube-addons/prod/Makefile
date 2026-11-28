# Platform tier (ingress, storage, DNS, Traefik, metrics). Apply before nonprod; destroy after it.
MODULES_DIR = ../../modules
# Pi-hole's API can't take concurrent writes: parallel record changes fail (EOF, connection
# reset or status 400) even though a record may still be saved. Change one at a time.
PARALLELISM = 1

include ../../terraform.mk
