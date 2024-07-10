# Contributing

When contributing to this repository, please first discuss the change you wish to make via issue,
email, or any other method with the owners of this repository before making a change.
Please note we have a [code of conduct](CODE_OF_CONDUCT.md),
please follow it in all your interactions with the project.

## Issues and feature requests

You've found a bug in the source code, a mistake in the documentation or maybe you'd like a new
feature? Take a look at [GitHub Discussions](https://github.com/starkware-libs/starknet-staking/discussions)
to see if it's already being discussed. You can help us by
[submitting an issue on GitHub](https://github.com/starkware-libs/starknet-staking/issues). Before you create
an issue, make sure to search the issue archive -- your issue may have already been addressed!

Please try to create bug reports that are:

- _Reproducible._ Include steps to reproduce the problem.
- _Specific._ Include as much detail as possible: which version, what environment, etc.
- _Unique._ Do not duplicate existing opened issues.
- _Scoped to a Single Bug._ One bug per report.

**Even better: Submit a pull request with a fix or new feature!**

## How to submit a Pull Request

1. Search our repository for open or closed
   [Pull Requests](https://github.com/starkware-libs/starknet-staking/pulls)
   that relate to your submission. You don't want to duplicate effort.
2. Fork the project
3. Create your feature branch (`git checkout -b feat/amazing_feature`)
4. Commit your changes (`git commit -m 'feat: add amazing_feature'`)
5. Push to the branch (`git push origin feat/amazing_feature`)
6. [Open a Pull Request](https://github.com/starkware-libs/starknet-staking/compare?expand=1)


## Development environment setup

In order to set up a development environment, First clone the repository:
```sh
git clone https://github.com/starkware-libs/starknet-staking
```

Then, you will need to install
- [Node](https://nodejs.org/en)
  - `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash`
  - `nvm install 20`
- [Pnpm](https://pnpm.io/)
  - `curl -fsSL https://get.pnpm.io/install.sh | sh -`
- [Turbo repo](https://turbo.build/)
  - `pnpm install turbo --global`

And run `pnpm install`
