module.exports =
  VERSION: require '../package.json' .version

  dora:
    akahai: [1 1 1] # number of 0m/p/s to replace 5m/p/s

    # kan:
    #   no => no kan-dora
    #   {daiminkan:, kakan:, ankan:} => kan-dora revealed:
    #     0 => after dahai / more kan
    #     1 => immediately
    kan:
      daiminkan: 0
      kakan: 0
      ankan: 1

    ura: yes
    kanUra: yes

  yaku:
    kuitan: yes # if tanyao is valid when not menzen
    kokushiAnkan: no # if ankan can be chankan'd for kokushi-musou

  # yakuman control:
  #   max: e.g. set to 2 to enable double yakuman
  #   (yakuman name): multiplier
  #     0 => not allowed
  #     1, 1.5, 2 => x times single yakuman
  # if not specified, all default to 1
  yakuman:
    max: 2
    /*
    daisuushi: 2
    suuankouTanki: 2
    junseichuurenpoutou: 2
    tenhou: 2
    chihou: 2
    kokushi13: 2
    */

  riichi:
    minPiipaiLeft: 4
    doubleRiichi: yes

    # ankan while riichi: extra rules even when allowed
    # see `Kyoku::canAnkan`
    ankan: yes
    okurikan: no

  ron:
    atamahane: no # only first player in natural turn order valid
    double: yes
    triple: no

  banKuikae:
    moro: yes # e.g. has 345m, 34m chi 0m => cannot dahai 5m
    suji: yes # e.g. has 234m, 34m chi 0m => cannot dahai 2m
    pon : no  # e.g. has 333m, 33m pon 3m => cannot dahai 3m

  # valid values:
  #   no: cannot ryoukyoku
  #   'oyanagare': can ryoukyoku but no renchan
  #   yes: can ryoukyoku and renchan
  ryoukyoku:
    kyuushuukyuuhai: yes
    nagashimangan: no # TODO
    tochuu:
      suufonrenta: yes
      suukaikan: yes
      suuchariichi: yes

  points:
    initial: 25000 # each player starts with `initial` points each kyoku
    origin: 30000 # game enters overtime if all players have points < `origin`
    riichi: 1000 # amount of kyoutaku given when riichi gets accepted
    howanpai: 3000 # total transferred amount at howanpai ryoukyoku
    honba: 100 # total of bonus points (*3 when ron) awarded for each honba

  # - normal game: play until `bakaze == end.normal`
  # - if oya renchan during last kyoku in normal game: game ends
  # - if no player has point at least `points.origin`: enter overtime
  # - overtime
  #   - always end when `bakaze == end.overtime`
  #   - end prematurely when some player reach `points.origin`:
  #     - sudden death: checked at end of a kyoku
  #     - otherwise: checked at end of a bakaze
  setup:
    points:
      initial: 25000
      origin: 30000 # overtime/sudden death starts if normal game completes but no one has point >= origin
    end:
      normal: 2
      overtime: 3
      suddenDeath: yes
      oyaALTop: yes
