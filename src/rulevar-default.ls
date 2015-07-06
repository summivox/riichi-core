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

  keishikiTenpai: # TODO
    sutehai: yes
    fuuro: yes
    dora: yes

  yaku:
    atotsuke: yes
    kuitan: yes # if tanyao is valid when not menzen
    kokushiAnkan: no # if ankan can be chankan'd for kokushi-musou

  riichi:
    minPiipaiLeft: 4
    doubleRiichi: yes
    minogashi: yes # TODO

    # ankan while riichi: extra rules even when allowed
    # see `Kyoku::canAnkan`
    ankan: yes
    okurikan: no # TODO

  ron:
    atamahane: no # only first player in natural turn order valid
    double: no
    triple: yes

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
