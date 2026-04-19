# Changelog

## [0.6.0](https://github.com/drifthoundhq/drifthound/compare/v0.5.1...v0.6.0) (2026-04-19)


### Features

* rework Slack notifications to always post new messages ([#134](https://github.com/drifthoundhq/drifthound/issues/134)) ([fdc2d97](https://github.com/drifthoundhq/drifthound/commit/fdc2d97f62f4533e36c6b923b0a9e65bdf40274b))


### Bug Fixes

* configure release-please to bump version file ([#128](https://github.com/drifthoundhq/drifthound/issues/128)) ([5e25f60](https://github.com/drifthoundhq/drifthound/commit/5e25f6021dfa8579c74033b36000c4d774e49298))
* Configure release-please version marker ([#130](https://github.com/drifthoundhq/drifthound/issues/130)) ([1328be4](https://github.com/drifthoundhq/drifthound/commit/1328be4413778116478e3359f478c0321dc65e58))
* point release workflow to config and manifest files ([#131](https://github.com/drifthoundhq/drifthound/issues/131)) ([79792fc](https://github.com/drifthoundhq/drifthound/commit/79792fccbc76586290cc808ee57a88e97ad8163c))
* use extra-files generic updater for version.rb ([#133](https://github.com/drifthoundhq/drifthound/issues/133)) ([0975560](https://github.com/drifthoundhq/drifthound/commit/0975560b53b841b381124fed37c6396fab656e64))
* use simple release type instead of generic ([#132](https://github.com/drifthoundhq/drifthound/issues/132)) ([083a299](https://github.com/drifthoundhq/drifthound/commit/083a299faf3744ed561767541f14cd27115654dc))

## [0.5.1](https://github.com/drifthoundhq/drifthound/compare/v0.5.0...v0.5.1) (2026-01-26)


### Bug Fixes

* Query projects with issues ([#111](https://github.com/drifthoundhq/drifthound/issues/111)) ([aafb19f](https://github.com/drifthoundhq/drifthound/commit/aafb19f7acce7677ff983a3d8f4316ddd2b137e8))

## [0.5.0](https://github.com/drifthoundhq/drifthound/compare/v0.4.0...v0.5.0) (2026-01-26)


### Features

* get endpoints ([#109](https://github.com/drifthoundhq/drifthound/issues/109)) ([7da92f5](https://github.com/drifthoundhq/drifthound/commit/7da92f54c4f636769bc7560fd9d9ffbee6924825))

## [0.4.0](https://github.com/drifthoundhq/drifthound/compare/v0.3.3...v0.4.0) (2025-12-21)


### Features

* API Token Management ([#88](https://github.com/drifthoundhq/drifthound/issues/88)) ([65f4421](https://github.com/drifthoundhq/drifthound/commit/65f44217dea6855fa8e630ef80bc770eece4db29))
* create render entrypoint ([#90](https://github.com/drifthoundhq/drifthound/issues/90)) ([6a60e8a](https://github.com/drifthoundhq/drifthound/commit/6a60e8a295abaf04874ab3f550407a92160b19be))
* enable public mode configuration ([#94](https://github.com/drifthoundhq/drifthound/issues/94)) ([52e7bf5](https://github.com/drifthoundhq/drifthound/commit/52e7bf561ba689f619ba1c20ff69ece6b8a3fcdf))
* GitHub oauth2 integration ([#89](https://github.com/drifthoundhq/drifthound/issues/89)) ([d89e4bd](https://github.com/drifthoundhq/drifthound/commit/d89e4bd69d2143e6d70301eb3e929de308c331be))
* RBAC and user management ([#86](https://github.com/drifthoundhq/drifthound/issues/86)) ([cf5e7bf](https://github.com/drifthoundhq/drifthound/commit/cf5e7bfd402e480806152e5fbd0c4663a0187f9b))


### Bug Fixes

* attempt to fix render entrypoint and improve debug information ([#92](https://github.com/drifthoundhq/drifthound/issues/92)) ([90dcd0c](https://github.com/drifthoundhq/drifthound/commit/90dcd0c960aa4c3595a80e9df47ef1d34da69059))
* make render-entrypoint executable ([#93](https://github.com/drifthoundhq/drifthound/issues/93)) ([db98fe8](https://github.com/drifthoundhq/drifthound/commit/db98fe850664346f42f46c6f614be108d4d60e58))

## [0.3.3](https://github.com/treezio/DriftHound/compare/v0.3.2...v0.3.3) (2025-12-15)


### Bug Fixes

* sanitize environment directory info ([#75](https://github.com/treezio/DriftHound/issues/75)) ([fa9d96c](https://github.com/treezio/DriftHound/commit/fa9d96cbd57118c41f1a1e3a61e9ad566d9513b4))

## [0.3.2](https://github.com/treezio/DriftHound/compare/v0.3.1...v0.3.2) (2025-12-15)


### Bug Fixes

* Sanitize repository input in both CLI and backend ([#73](https://github.com/treezio/DriftHound/issues/73)) ([11e54b4](https://github.com/treezio/DriftHound/commit/11e54b427a9fefed8a7463127116976b48e5010b))

## [0.3.1](https://github.com/treezio/DriftHound/compare/v0.3.0...v0.3.1) (2025-12-15)


### Bug Fixes

* credentials check when executing assets precompilation ([#71](https://github.com/treezio/DriftHound/issues/71)) ([6b49f46](https://github.com/treezio/DriftHound/commit/6b49f467ed51ed0952a4ee81abc59f425ab40264))

## [0.3.0](https://github.com/treezio/DriftHound/compare/v0.2.12...v0.3.0) (2025-12-15)


### Features

* admin login ([#61](https://github.com/treezio/DriftHound/issues/61)) ([a9062b9](https://github.com/treezio/DriftHound/commit/a9062b94250acf91dea8ec21b37c805cd5df9a19))
* Configure data retention mechanism and policy ([#65](https://github.com/treezio/DriftHound/issues/65)) ([ef29c19](https://github.com/treezio/DriftHound/commit/ef29c1915d0edb6aa4c056555bec41fede35e3b8))
* Dashboard charts ([#62](https://github.com/treezio/DriftHound/issues/62)) ([960a0e7](https://github.com/treezio/DriftHound/commit/960a0e7da4f2e37b1025b083cf5d2c1c86556052))
* Enhance project and environment information ([#57](https://github.com/treezio/DriftHound/issues/57)) ([4c656f2](https://github.com/treezio/DriftHound/commit/4c656f2332dc246518a4a03f453ea53ac8cf25f9))
* Improve UX looks and long names handling ([#59](https://github.com/treezio/DriftHound/issues/59)) ([a130288](https://github.com/treezio/DriftHound/commit/a13028840e6656b80ef808c1b9b06583ea8378ab))
* Refactor seeding data into different tasks ([#66](https://github.com/treezio/DriftHound/issues/66)) ([61770e5](https://github.com/treezio/DriftHound/commit/61770e525a230e4674af91b09fa11faf6592a789))
* Slack information GUI ([#60](https://github.com/treezio/DriftHound/issues/60)) ([e9df3f1](https://github.com/treezio/DriftHound/commit/e9df3f1cadb2c0b92e8430427c51a28f2ef6347e))


### Bug Fixes

* minor improvements and disable lock ([9616416](https://github.com/treezio/DriftHound/commit/9616416aa40cffa1592ae54db2abaf2622a19449))
* smart history data backfill in seed file ([#63](https://github.com/treezio/DriftHound/issues/63)) ([6c0d53a](https://github.com/treezio/DriftHound/commit/6c0d53aa9ce8f321432f6b7021fde24623e21b83))
* use -detailed-exitcode ([b245ea4](https://github.com/treezio/DriftHound/commit/b245ea4316a5787ab04e4843333c9b73fdd0482f))

## [0.2.12](https://github.com/treezio/DriftHound/compare/v0.2.11...v0.2.12) (2025-12-11)


### Bug Fixes

* Update message content for resolved state ([#54](https://github.com/treezio/DriftHound/issues/54)) ([1790dec](https://github.com/treezio/DriftHound/commit/1790dec5663a3b5f2d9077c902cce595aa498246))

## [0.2.11](https://github.com/treezio/DriftHound/compare/v0.2.10...v0.2.11) (2025-12-11)


### Bug Fixes

* Missing notifications and improve seeding tests ([#51](https://github.com/treezio/DriftHound/issues/51)) ([096a39a](https://github.com/treezio/DriftHound/commit/096a39a83bbe810060402ddc1fa019288cb5432c))

## [0.2.10](https://github.com/treezio/DriftHound/compare/v0.2.9...v0.2.10) (2025-12-10)


### Bug Fixes

* remove production cache config ([#48](https://github.com/treezio/DriftHound/issues/48)) ([dba2068](https://github.com/treezio/DriftHound/commit/dba20685760409afeb081bbf99b2e4f48252805c))

## [0.2.9](https://github.com/treezio/DriftHound/compare/v0.2.8...v0.2.9) (2025-12-10)


### Bug Fixes

* docker cmd and docker compose port ([#46](https://github.com/treezio/DriftHound/issues/46)) ([b154369](https://github.com/treezio/DriftHound/commit/b154369f972a331dbf03ab91d51c60b66c78896a))

## [0.2.8](https://github.com/treezio/DriftHound/compare/v0.2.7...v0.2.8) (2025-12-10)


### Bug Fixes

* Configure production mode for basic app ([#44](https://github.com/treezio/DriftHound/issues/44)) ([fcdbe73](https://github.com/treezio/DriftHound/commit/fcdbe733b46c2aa900b48edf1efa6b540a7f60fc))

## [0.2.7](https://github.com/treezio/DriftHound/compare/v0.2.6...v0.2.7) (2025-12-06)


### Bug Fixes

* Add database host environment variable and fix gemfile issues ([#40](https://github.com/treezio/DriftHound/issues/40)) ([0a02f97](https://github.com/treezio/DriftHound/commit/0a02f97ae4ae3201562da9edafdcd991578d27cc))

## [0.2.6](https://github.com/treezio/DriftHound/compare/v0.2.5...v0.2.6) (2025-12-02)


### Bug Fixes

* Set project name as key ([#36](https://github.com/treezio/DriftHound/issues/36)) ([757e186](https://github.com/treezio/DriftHound/commit/757e186cadf27c594c4d07f78b45964804b5c8c0))

## [0.2.5](https://github.com/treezio/DriftHound/compare/v0.2.4...v0.2.5) (2025-12-01)


### Bug Fixes

* Set github token in release please action properly ([#28](https://github.com/treezio/DriftHound/issues/28)) ([5bc4f68](https://github.com/treezio/DriftHound/commit/5bc4f68ee0343bfcc80117f621605ced48386ab7))

## [0.2.4](https://github.com/treezio/DriftHound/compare/v0.2.3...v0.2.4) (2025-12-01)


### Bug Fixes

* Set high res logo in dashboard ([#26](https://github.com/treezio/DriftHound/issues/26)) ([f756687](https://github.com/treezio/DriftHound/commit/f756687cad0bb9d7059a2041018908e81ae38676))

## [0.2.3](https://github.com/treezio/DriftHound/compare/v0.2.2...v0.2.3) (2025-12-01)


### Bug Fixes

* remove doggo emoji ([#24](https://github.com/treezio/DriftHound/issues/24)) ([97910ec](https://github.com/treezio/DriftHound/commit/97910ec2d7347ae635cb676fe51ad3709daed234))

## [0.2.1](https://github.com/treezio/DriftHound/compare/v0.2.0...v0.2.1) (2025-12-01)


### Bug Fixes

* Trigger docker build push release whenever release is created ([397706d](https://github.com/treezio/DriftHound/commit/397706de3dd93f7f2c3ec2552cc1854eb4acc3cc))
* Release Docker Image ([d3c5c02](https://github.com/treezio/DriftHound/commit/d3c5c02047491d4afbef0371bce53b6232a2de93))

## [0.2.0](https://github.com/treezio/DriftHound/compare/v0.1.0...v0.2.0) (2025-11-30)


### Features

* Create notifications system ([8b57be7](https://github.com/treezio/DriftHound/commit/8b57be7a97da520695eb385066c0546f41b782af))
* Docker Release ([8989412](https://github.com/treezio/DriftHound/commit/8989412059ddfc8da779e622ea6a043603745240))
* Run CLI from Docker Image ([0969ff3](https://github.com/treezio/DriftHound/commit/0969ff3b21c13d401f686cf3ec54fa6b70d5d388))


### Bug Fixes

* attempt to fix test execution issues in github actions ([fc26568](https://github.com/treezio/DriftHound/commit/fc26568ac47578554a83b0824f4990f470b874f9))
* attempt to fix test execution issues in github actions ([04f29a8](https://github.com/treezio/DriftHound/commit/04f29a8ac6e1cb4476b8faacc4a5d80890cb8cab))
* attempt to fix test execution issues in github actions ([684097f](https://github.com/treezio/DriftHound/commit/684097f2ab08d0ccdd76b52b19a0125fc9157aa1))
* force image generation ([a840873](https://github.com/treezio/DriftHound/commit/a84087395ff669bbfc700c620bd168bc21ded41d))
* Ignore claude config ([df0c0ef](https://github.com/treezio/DriftHound/commit/df0c0ef8a38f02e395e686260ee6f2e275946db6))
* repository name ([685ba05](https://github.com/treezio/DriftHound/commit/685ba05e165253064de2b1a8e06c9ba3e2009b32))
* testing execution issues emulating CI in local env ([3864ee1](https://github.com/treezio/DriftHound/commit/3864ee14d18d09faeed996710e8c236061de0b28))
* tests execution ([d6397bd](https://github.com/treezio/DriftHound/commit/d6397bd9bc357a953a76bfb11c5fd0c599039167))

## 0.1.0 (2025-11-29)


### Features

* include automatic release ([07f223c](https://github.com/treezio/DriftHound/commit/07f223ce2e47ae92a64a12e7d23af5e5b208a0e9))
* Update release please config ([a0c691d](https://github.com/treezio/DriftHound/commit/a0c691d77905480aa042eae27a7a63f1a0188acf))
* Use release please v3 ([638cf3f](https://github.com/treezio/DriftHound/commit/638cf3fa8065415db02f7099551dbb3efb11cc61))


### Bug Fixes

* set version ([67ae051](https://github.com/treezio/DriftHound/commit/67ae051ec37bfdc270f852d4c3c24d38a80dfe17))
* testing failures ([d1c0d60](https://github.com/treezio/DriftHound/commit/d1c0d6046aca76ec633217c55f69573dfadc03e6))


### Miscellaneous Chores

* release 0.1.0 ([0e3544a](https://github.com/treezio/DriftHound/commit/0e3544ae7e505869a8391e4f8d765afcf7a37a2c))
