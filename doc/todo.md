## Almanah TODO

- **High priority**
  - create buildstream package for Almanah
    You can get Buildstream in a toolbox container:
    $ toolbox create -i registry.gitlab.com/freedesktop-sdk/infrastructure/freedesktop-sdk-docker-images/bst2
    For quick start you can check ../../gnome-build-meta or ../../buildstream
    Make this in a separate branch
  - 

- **Add images or sketches**
  - 

- **Evolution integration**
  - Finish wiring `EvolutionEventsProvider` to libecal/libedataserver.
  - Populate the “Past events” list with real Evolution calendar data.

- **Encryption**
  - Verify GPG-based content encryption/decryption on multiple setups.
  - Consider migrating existing plaintext entries automatically when a key is chosen.
