
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
The project is build with [Turbo repo](https://turbo.build/) and [pnpm](https://pnpm.io/).  
Turbo's installation process will also install the cairo dependencies such as [Scarb](https://docs.swmansion.com/scarb/) and [Starknet foundry](https://foundry-rs.github.io/starknet-foundry/index.html).

## Installation
Clone the repo and from within the projects root folder run:
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
nvm install 20
curl -fsSL https://get.pnpm.io/install.sh | sh -
pnpm install turbo --global
pnpm install
```

## Implementation specification
Specs document found [here](docs/spec.md)

## Verify Class Hash
To ensure that the on-chain class hash corresponds to the code in this repository, follow these steps:
- :wrench: Environment Requirements
  - scarb version:
    - `scarb --version` -> `2.11.2`
    - if not, install scarb:
      - `asdf install scarb 2.11.2`
      - `asdf global scarb 2.11.2`
  - starkli version:
    - `starkli --version` -> `0.4.1`
- :mag: Verification Steps
  - Checkout the Correct Code Version
    - Make sure you're on the exact Git commit or tag used for deployment:
      - `git checkout <commit-hash-or-tag>`
      - commit_hash: `06d2fffb288937ed76d58165debe46f1796273c1`
      - tag: `@staking/contracts-v1.0.1-dev.510`
  - Build the Contract
    - Use Scarb to compile the contract:
      - `scarb build`
  - Compute the Local Class Hash
    - Use Starkli to calculate the class hash from the compiled contract:
      - `starkli class-hash target/dev/staking_X.contract_class.json`
      - where `X` is the name of the contract (e.g. `Staking`, `Attestation`)
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

