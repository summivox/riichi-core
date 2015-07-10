module.exports = 
  VERSION: '0.1.0'

  dora:
    akahai: [1, 1, 1] # number of 0m/p/s to replace 5m/p/s

    # kan:
    #   no => no kan-dora
    #   {daiminkan:, kakan:, ankan:} => kan-dora revealed:
    #     0 => immediately
    #     1 => after dahai {discard} / more kan
    kan:
      daiminkan: 1
      kakan: 1
      ankan: 0

    ura: yes
    kanUra: yes

  yaku:
    atotsuke: yes # TODO
    kuitan: yes # if tanyao is valid when not menzen
    kokushiAnkan: no # if ankan can be chankan'd for kokushi-musou
  
  # yakuman control:
  #   max: e.g. set to 2 to enable double yakuman
  #   (yakuman name): multiplier
  #     0 => not allowed
  #     1, 1.5, 2 => x times single yakuman
  # if not specified, all default to 1
  yakuman:
    max: 1
    /*
    daisuushi: 2
    suuankouTanki: 2
    junseichuurenpoutou: 2
    tenhou: 2
    chihou: 2
    */

  riichi:
    minPiipaiLeft: 4
    doubleRiichi: yes
    minogashi: yes # TODO
    autoTsumokiri: yes # DEBUG

    # ankan while riichi: extra rules even when allowed
    # see `Kyoku::canAnkan`
    ankan: yes
    okurikan: no # TODO

  ron:
    atamahane: no # only first player in natural turn order valid
    double: yes
    triple: no

  banKuikae:
    moro: yes # e.g. has 34m , chi 0m => cannot dahai 5m
    suji: yes # e.g. has 34m , chi 0m => cannot dahai 2m
    pon : no  # e.g. has 333m, pon 3m => cannot dahai 3m

  # valid values:
  #   no: cannot ryoukyoku
  #   'oyanagare': can ryoukyoku but no renchan
  #   yes: can ryoukyoku and renchan
  ryoukyoku:
    kyuushuukyuuhai: yes
    nagashimankan: yes # TODO
    tochuu:
      suufonrenta: yes
      suukaikan: yes
      suuchariichi: yes
