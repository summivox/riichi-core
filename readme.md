# `riichi-core`: JS Riichi Mahjong game engine

<!-- badges -->
<!-- depends on shields.io -->

[![npm](https://img.shields.io/npm/v/riichi-core.svg?maxAge=86400?style=plastic)](https://www.npmjs.com/package/riichi-core) [![GitHub license](https://img.shields.io/badge/license-GPLv3-lightgrey.svg?style=plastic)](https://raw.githubusercontent.com/summivox/riichi-core/master/LICENSE) [![GitHub stars](https://img.shields.io/github/stars/summivox/riichi-core.svg?style=social&label=Star&maxAge=86400)](https://github.com/summivox/riichi-core) [![Twitter URL](https://img.shields.io/twitter/url/http/github.com/summivox/riichi-core.svg?style=social&maxAge=86400?style=plastic)](http://twitter.com/share?text=riichi-core%3A%20open%20source%20%23javascript%20riichi%20%23mahjong%20game%20engine&url=https%3A%2F%2Fgithub.com%2Fsummivox%2Friichi-core&via=summivox&hashtags=nodejs,npm)

<!-- /badges -->

`riichi-core` is a CommonJS library that implements the game of [Riichi Mahjong / リーチ麻雀][en-wp-riichi], a popular modern Japanese variant of the traditional Chinese table game of Mahjong.

[en-wp-riichi]: https://en.wikipedia.org/wiki/Japanese_Mahjong

## Features

* Consistent, canonical, non-confusing terminology
* Customizable rule variations (excluding so-called "local rules")
* Clean, intuitive API
* Event sourcing architecture
	* deterministic behavior
	* succinct game logs
	* built-in client-server capability
* [Free software](https://www.gnu.org/philosophy/free-sw.en.html)


## [Full Documentation](doc/index.md)


## Contributing

Issues and pull requests are welcome.

The project is mostly written in [LiveScript][], a compile-to-javascript language.

[mocha][] and [istanbul][] are used to run the [tests](test). Data used in some tests are *not* commited to repo as of now due to copyright concerns.


[LiveScript]: http://livescript.net/
[mocha]: https://mochajs.org/
[istanbul]: https://www.npmjs.com/package/istanbul


## [Changelog](changelog.md)

## License

[GPLv3](LICENSE).

If you find this library helpful or are using / plan to use this library in your project, please kindly drop me a note on Twitter ([@summivox](https://twitter.com/summivox)). I appreciate it.