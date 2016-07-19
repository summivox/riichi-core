# Changelog
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [unreleased]

### Changed

* API: `Kyoku#begin` is renamed to `Kyoku#go` (avoid confusion with `Kyoku#phase` value `'begin'`)
* API: `rulevar.setup.end.oyaALTop` is renamed to `rulevar.setup.end.agariyame` (canonical name)


## [1.0.2] - 2016-06-16

### Fixed
* Dependency case mismatch (`71a4b2fa`)

## [1.0.0] - 2016-06-12

First release.

### Known Issues
* incomplete documentation
* missing feature: nagashi-mangan
* incomplete feature: okurikan
* missing minor feature: convert game log to tenhou6 format
* missing minor feature: reconstruction of revealed juntehai on replicate kyoku instances after agari or howanpai tenpai