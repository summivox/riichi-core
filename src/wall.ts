/**
 * Create new sorted wall as an array of pai.
 * Each distinct pai is repeated 4 times, then some 5m/5p/5s are replaced with
 * 0m/0p/0s (akadora) respectively.
 *
 * @export
 * @param {number} [m0=1] number of 0m to replace 5m in the wall (0/1/2/3/4)
 * @param {number} [p0=1] number of 0p to replace 5p in the wall (0/1/2/3/4)
 * @param {number} [s0=1] number of 0s to replace 5s in the wall (0/1/2/3/4)
 * @returns
 */
export function create(m0 = 1, p0 = 1, s0 = 1) {
    return [
        1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4,
        m0 >= 1 ? 0 : 5,
        m0 >= 2 ? 0 : 5,
        m0 >= 3 ? 0 : 5,
        m0 >= 4 ? 0 : 5,
        6, 6, 6, 6, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 9,

        11, 11, 11, 11, 12, 12, 12, 12, 13, 13, 13, 13, 14, 14, 14, 14,
        p0 >= 1 ? 10 : 15,
        p0 >= 2 ? 10 : 15,
        p0 >= 3 ? 10 : 15,
        p0 >= 4 ? 10 : 15,
        16, 16, 16, 16, 17, 17, 17, 17, 18, 18, 18, 18, 19, 19, 19, 19,

        21, 21, 21, 21, 22, 22, 22, 22, 23, 23, 23, 23, 24, 24, 24, 24,
        s0 >= 1 ? 20 : 25,
        s0 >= 2 ? 20 : 25,
        s0 >= 3 ? 20 : 25,
        s0 >= 4 ? 20 : 25,
        26, 26, 26, 26, 27, 27, 27, 27, 28, 28, 28, 28, 29, 29, 29, 29,

        30, 30, 30, 30, 31, 31, 31, 31, 32, 32, 32, 32, 33, 33, 33, 33, 34, 34, 34, 34, 35, 35, 35, 35, 36, 36, 36, 36
    ];
}

export interface WallParts {
    haipai: number[/*4*/][/*13*/];
    piipai: number[/*70*/];
    rinshan: number[/*4*/];
    doraHyouji: number[/*5*/];
    uraDoraHyouji: number[/*5*/];
}

export function toParts(wall: number[]): WallParts {
    const z = wall;
    return {
        haipai: [
            [
                z[0x00], z[0x01], z[0x02], z[0x03],
                z[0x10], z[0x11], z[0x12], z[0x13],
                z[0x20], z[0x21], z[0x22], z[0x23], z[0x30]],
            [
                z[0x04], z[0x05], z[0x06], z[0x07],
                z[0x14], z[0x15], z[0x16], z[0x17],
                z[0x24], z[0x25], z[0x26], z[0x27], z[0x31]],
            [
                z[0x08], z[0x09], z[0x0A], z[0x0B],
                z[0x18], z[0x19], z[0x1A], z[0x1B],
                z[0x28], z[0x29], z[0x2A], z[0x2B], z[0x32]],
            [
                z[0x0C], z[0x0D], z[0x0E], z[0x0F],
                z[0x1C], z[0x1D], z[0x1E], z[0x1F],
                z[0x2C], z[0x2D], z[0x2E], z[0x2F], z[0x33]],
        ],
        piipai: [
            z[121], z[120], z[119], z[118], z[117], z[116], z[115], z[114], z[113], z[112],
            z[111], z[110], z[109], z[108], z[107], z[106], z[105], z[104], z[103], z[102],
            z[101], z[100], z[99], z[98], z[97], z[96], z[95], z[94], z[93], z[92],
            z[91], z[90], z[89], z[88], z[87], z[86], z[85], z[84], z[83], z[82],
            z[81], z[80], z[79], z[78], z[77], z[76], z[75], z[74], z[73], z[72],
            z[71], z[70], z[69], z[68], z[67], z[66], z[65], z[64], z[63], z[62],
            z[61], z[60], z[59], z[58], z[57], z[56], z[55], z[54], z[53], z[52]
        ],
        rinshan: [z[133], z[132], z[135], z[134]],
        doraHyouji: [z[130], z[128], z[126], z[124], z[122]],
        uraDoraHyouji: [z[131], z[129], z[127], z[125], z[123]],
    };
}

export function fromParts(parts: WallParts): number[] {
    const {
        haipai: [e, s, w, n],
        piipai: p,
        rinshan: r,
        doraHyouji: d,
        uraDoraHyouji: u,
    } = parts;
    return [
        // haipai
        e[0x0], e[0x1], e[0x2], e[0x3],
        s[0x0], s[0x1], s[0x2], s[0x3],
        w[0x0], w[0x1], w[0x2], w[0x3],
        n[0x0], n[0x1], n[0x2], n[0x3],

        e[0x4], e[0x5], e[0x6], e[0x7],
        s[0x4], s[0x5], s[0x6], s[0x7],
        w[0x4], w[0x5], w[0x6], w[0x7],
        n[0x4], n[0x5], n[0x6], n[0x7],

        e[0x8], e[0x9], e[0xa], e[0xb],
        s[0x8], s[0x9], s[0xa], s[0xb],
        w[0x8], w[0x9], w[0xa], w[0xb],
        n[0x8], n[0x9], n[0xa], n[0xb],

        e[0xc], s[0xc], w[0xc], n[0xc],

        // piipai (reverse)
        p[69], p[68], p[67], p[66], p[65], p[64], p[63], p[62], p[61], p[60],
        p[59], p[58], p[57], p[56], p[55], p[54], p[53], p[52], p[51], p[50],
        p[49], p[48], p[47], p[46], p[45], p[44], p[43], p[42], p[41], p[40],
        p[39], p[38], p[37], p[36], p[35], p[34], p[33], p[32], p[31], p[30],
        p[29], p[28], p[27], p[26], p[25], p[24], p[23], p[22], p[21], p[20],
        p[19], p[18], p[17], p[16], p[15], p[14], p[13], p[12], p[11], p[10],
        p[9], p[8], p[7], p[6], p[5], p[4], p[3], p[2], p[1], p[0],

        // doraHyouji
        d[4], u[4], d[3], u[3], d[2], u[2], d[1], u[1], d[0], u[0],

        // rinshan (reverse)
        r[1], r[0], r[3], r[2],
    ];
}
