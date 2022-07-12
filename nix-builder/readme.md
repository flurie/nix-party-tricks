# Phase zero: sui generis

We need a builder, and we could build a builder if we had a builder, but we don't. So we need a builder we don't have to build.

One way to get a builder is to use a remote machine. Another way is to use a VM or container locally. This is some setup for a containerized builder on a macOS machine.

I decided not to use a remote builder in the demo in order to make the setup easier, but it is still possible to do, and I have done it without too much effort, though the Dockerfile looks unsavory. Theoretically one could use this to boostrap a much better image that is made with nix.
