describe "Pai", ->
  Pai = require '../src/pai.js'

  forSuupai = (cb) ->
    suites = ['m', 'p', 's']
    for n in [0..9]
      for m in [0..2]
        paiStr = n + suites[m]
        cb(paiStr, n, m, suites[m])
  forTsuupai = (cb) ->
    for n in [1..7]
      paiStr = n + 'z'
      cb(paiStr, n)
  forFonpai = (cb) ->
    for n in [1..4]
      paiStr = n + 'z'
      cb(paiStr, n)
  forSangenpai = (cb) ->
    for n in [5..7]
      paiStr = n + 'z'
      cb(paiStr, n)

  it "can be constructed from suupai shorthands", ->
    forSuupai (paiStr) ->
      pai = null
      expect(-> pai = Pai paiStr).not.toThrow()
      expect(pai.toString()).toEqual(paiStr)

  it "can be constructed from tsuupai canonical shorthands", ->
    forTsuupai (paiStr) ->
      pai = null
      expect(-> pai = Pai paiStr).not.toThrow()
      expect(pai.toString()).toEqual(paiStr)

  it "can be constructed from tsuupai alternative shorthands", ->
    alt1 = '#ESWNBGR'
    alt2 = '#ESWNPFC'
    alt3 = '#ESWNDHT'
    for n in [1..7]
      paiStr1 = alt1[n]
      paiStr2 = alt2[n]
      paiStr3 = alt3[n]
      pai1 = null
      pai2 = null
      pai3 = null
      expect(-> pai1 = Pai paiStr1).not.toThrow()
      expect(-> pai2 = Pai paiStr2).not.toThrow()
      expect(-> pai3 = Pai paiStr3).not.toThrow()
      expect(pai1.toString()).toEqual(n + 'z')
      expect(pai2.toString()).toEqual(n + 'z')
      expect(pai3.toString()).toEqual(n + 'z')

  it "cannot be constructed from invalid shorthands", ->
    expect(-> Pai '0z').toThrow()
    expect(-> Pai 'garbage').toThrow()

  it "should be immutable", ->
    pai = Pai '0m'
    expect(pai.toString()).toEqual('0m')
    pai.pai = 'garbage'
    expect(pai.toString()).toEqual('0m')
    pai.garbage = 'garbage'
    expect(pai).not.toContain('garbage')

  it "can test equality to other Pai", ->
    pai1 = Pai '3s'
    pai2 = Pai '3s'
    expect(pai1.isEqualTo(pai2)).toBe(true)
    expect(pai2.isEqualTo(pai1)).toBe(true)

  it "can extract parts of tile (number + suite)", ->
    forSuupai (paiStr, n, m, suite) ->
      pai = Pai paiStr
      expect(pai.number()).toEqual(n)
      expect(pai.suite()).toEqual(suite)
    forTsuupai (paiStr, n) ->
      pai = Pai paiStr
      expect(pai.number()).toEqual(n)
      expect(pai.suite()).toEqual('z')


  describe "category testing", ->

    it "can correctly test categories for suupai", ->
      forSuupai (paiStr, n, m, suite) ->
        pai = Pai paiStr
        expect(pai.isSuupai()).toBe(true)
        expect(pai.isTsuupai()).toBe(false)
        switch m
          when 0
            expect(pai.isManzu()).toBe(true)
            expect(pai.isPinzu()).toBe(false)
            expect(pai.isSouzu()).toBe(false)
          when 1
            expect(pai.isManzu()).toBe(false)
            expect(pai.isPinzu()).toBe(true)
            expect(pai.isSouzu()).toBe(false)
          when 2
            expect(pai.isManzu()).toBe(false)
            expect(pai.isPinzu()).toBe(false)
            expect(pai.isSouzu()).toBe(true)
        switch n
          when 0
            expect(pai.isAkahai()).toBe(true)
            expect(pai.isRaotoupai()).toBe(false)
            expect(pai.isChunchanpai()).toBe(true)
            expect(pai.isYaochuupai()).toBe(false)
          when 1, 9
            expect(pai.isAkahai()).toBe(false)
            expect(pai.isRaotoupai()).toBe(true)
            expect(pai.isChunchanpai()).toBe(false)
            expect(pai.isYaochuupai()).toBe(true)
          else
            expect(pai.isAkahai()).toBe(false)
            expect(pai.isRaotoupai()).toBe(false)
            expect(pai.isChunchanpai()).toBe(true)
            expect(pai.isYaochuupai()).toBe(false)

    it "can correctly test categories for fonpai", ->
      forFonpai (paiStr, n) ->
        pai = Pai paiStr
        expect(pai.isSuupai()).toBe(false)
        expect(pai.isTsuupai()).toBe(true)

        expect(pai.isManzu()).toBe(false)
        expect(pai.isPinzu()).toBe(false)
        expect(pai.isSouzu()).toBe(false)

        expect(pai.isAkahai()).toBe(false)
        expect(pai.isRaotoupai()).toBe(false)
        expect(pai.isChunchanpai()).toBe(false)

        expect(pai.isFonpai()).toBe(true)
        expect(pai.isSangenpai()).toBe(false)
        expect(pai.isYaochuupai()).toBe(true)

    it "can correctly test categories for sangenpai", ->
      forSangenpai (paiStr, n) ->
        pai = Pai paiStr
        expect(pai.isSuupai()).toBe(false)
        expect(pai.isTsuupai()).toBe(true)

        expect(pai.isManzu()).toBe(false)
        expect(pai.isPinzu()).toBe(false)
        expect(pai.isSouzu()).toBe(false)

        expect(pai.isAkahai()).toBe(false)
        expect(pai.isRaotoupai()).toBe(false)
        expect(pai.isChunchanpai()).toBe(false)

        expect(pai.isFonpai()).toBe(false)
        expect(pai.isSangenpai()).toBe(true)
        expect(pai.isYaochuupai()).toBe(true)

  describe "dora handling", ->

    it "should report correct equivalent pai for all suupai", ->
      forSuupai (paiStr, n, m, suite) ->
        pai = Pai paiStr
        if n == 0
          expect(pai.equivNumber()).toEqual(5)
          expect(pai.equivPai().toString()).toEqual(5 + suite)
        else
          expect(pai.equivNumber()).toEqual(n)
          expect(pai.equivPai().toString()).toEqual(n + suite)

    it "should report correct equivalent pai for all tsuupai", ->
      forTsuupai (paiStr, n) ->
        pai = Pai paiStr
        expect(pai.equivNumber()).toEqual(n)

    it "can test equivalance to another pai", ->
      a = Pai '0p'
      b = Pai '5p'
      c = Pai '0s'
      d = Pai '5s'
      expect(Pai('0p').isEquivTo(Pai('5p'))).toBe(true)
      expect(Pai('5s').isEquivTo(Pai('0s'))).toBe(true)
      expect(Pai('0p').isEquivTo(Pai('0s'))).toBe(false)
      expect(Pai('1m').isEquivTo(Pai('1z'))).toBe(false)

    it "can calculate correct dora from suupai dora indicator", ->
      forSuupai (paiStr, n, m, suite) ->
        pai = Pai paiStr
        succStr = pai.succ().toString()
        switch n
          when 0
            expect(succStr).toEqual(6 + suite)
          when 9
            expect(succStr).toEqual(1 + suite)
          else
            expect(succStr).toEqual((n+1) + suite)

    it "can calculate correct dora from fonpai dora indicator", ->
      expect(Pai('E').succ().toString()).toEqual('2z')
      expect(Pai('S').succ().toString()).toEqual('3z')
      expect(Pai('W').succ().toString()).toEqual('4z')
      expect(Pai('N').succ().toString()).toEqual('1z')

    it "can calculate correct dora from sangenpai dora indicator", ->
      expect(Pai('B').succ().toString()).toEqual('6z')
      expect(Pai('F').succ().toString()).toEqual('7z')
      expect(Pai('Z').succ().toString()).toEqual('5z')

    it "can test if it is successor of another pai", ->
      expect(Pai('F').isSuccOf(Pai('P'))).toBe(true)
      expect(Pai('F').isSuccOf(Pai('F'))).toBe(false)
      expect(Pai('F').isSuccOf(Pai('C'))).toBe(false)
      expect(Pai('0m').isSuccOf(Pai('4m'))).toBe(true)
      expect(Pai('6p').isSuccOf(Pai('0p'))).toBe(true)

  describe "literals", ->
    it "has correct succ links", ->
      expect(Pai['0m'].succ).toBe(Pai['6m'])
      expect(Pai['F'].succ).toBe(Pai['C'])
      expect(Pai['4p'].succ).toBe(Pai['5p'].equivPai)
