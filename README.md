
<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/starknet-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/starknet-light.png">
  <img alt="Your logo" src="assets/starknet-light.png">
</picture>
</div>

<div align="center">

[![License: Apache2.0](https://img.shields.io/badge/License-Apache2.0-green.svg)](LICENSE)
</div>

# Starknet Staking <!-- omit from toc -->

## Table of contents <!-- omit from toc -->

 <!-- omit from toc -->
- [About](#about)
- [Disclaimer](#disclaimer)
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Implementation specification](#implementation-specification)
- [Getting help](#getting-help)
- [Help make Staking better!](#help-make-staking-better)
- [Contributing](#contributing)
- [Security](#security)


## About
This repo holds the implementation of Staknet's staking mechanism.  
Following [Starknet SNIP 18](https://community.starknet.io/t/snip-18-staking-s-first-stage-on-starknet/114334).

## Disclaimer
Staking is a work in progress.

## Dependencies
- [Scarb](https://docs.swmansion.com/scarb/)
- [Starknet foundry](https://foundry-rs.github.io/starknet-foundry/index.html) (optional - for testing)

## Installation
Install the dependencies (either using [asdf](https://asdf-vm.com/) or any other way),
clone the repo and from within the project's root folder run:
```bash
scarb build
```
for a development build or
```bash
scarb --release build
```
for a release build.

## Implementation specification
Specs document found [here](docs/spec.md)

## Verify Class Hash
To ensure that the on-chain class hash corresponds to the code in this repository, follow these steps:
- :wrench: Environment Requirements
  - sncast version:
    - `sncast --version` -> `0.50.0`
    - if not, install sncast:
      - `asdf install starknet-foundry 0.50.0`
      - `asdf global starknet-foundry 0.50.0`
      - `asdf local starknet-foundry 0.50.0`
- :mag: Verification Steps
  - Checkout the Correct Code Version
    - Make sure you're on the exact Git commit or tag used for deployment:
      - `git checkout <commit-hash-or-tag>`
      - commit_hash: `5c11a5689f2d2e08ffecebf30d3e49569accbfca`
      - tag: `@staking/contracts-v1.0.1-dev.854`
  - Compute the Local Class Hash
    - Use Sncast to calculate the class hash of the local contract:
      - `sncast utils class-hash --contract-name <contract_name>`
      - where `<contract_name>` is the name of the contract (e.g. `Staking`, `Attestation`)
  - Compare with On-Chain Class Hash
    - Look up the deployed class hash on a block explorer (e.g., [StarkScan](https://starkscan.io/) or [Voyager](https://voyager.online/))
    - Ensure it matches the one computed locally
  
## Getting help

Reach out to the maintainer at any of the following:
- [GitHub Discussions](https://github.com/starkware-libs/starknet-staking/discussions)
- Contact options listed on this [GitHub profile](https://github.com/starkware-libs)

## Help make Staking better!

If you want to say thank you or support the active development of Starknet Staking:
- Add a GitHub Star to the project.
- Tweet about Starknet Staking.
- Write interesting articles about the project on [Dev.to](https://dev.to/), [Medium](https://medium.com), or your personal blog.

## Contributing
Thanks for taking the time to contribute! Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make benefit everybody else and are greatly appreciated.

Please read our [contribution guidelines](https://github.com/starkware-libs/starknet-staking/blob/main/docs/CONTRIBUTING.md), and thank you for being involved!

## Security
Starknet Staking follows good practices of security, but 100% security cannot be assured. Starknet Staking is provided "as is" without any warranty. Use at your own risk.

For more information and to report security issues, please refer to our [security documentation](https://github.com/starkware-libs/starknet-staking/blob/main/docs/SECURITY.md).

