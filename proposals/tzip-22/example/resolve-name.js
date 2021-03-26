const { InMemorySigner } = require('@taquito/signer');
const { TezosToolkit } = require('@taquito/taquito');
const { Tzip16Module, tzip16 } = require('@taquito/tzip16');

/**
 * Converts a string to UTF-8 bytes and returns them in hexadecimal format.
 * 
 * @param {string} str input string
 * @returns string the string converted to bytes in hexadecimal format
 */
function encodeString(str) {
    var result = '';
    var encoded = new TextEncoder().encode(str);
    for (let i = 0; i < encoded.length; i++) {
        let hexchar = encoded[i].toString(16);
        result += hexchar.length == 2 ? hexchar : '0' + hexchar;
    }
    return result;
}

(async () => {
    // create a contract instance equipped to handle tzip-16 calls
    const tezos = new TezosToolkit('https://edonet.smartpy.io/');
    tezos.addExtension(new Tzip16Module());
    tezos.setSignerProvider(await InMemorySigner.fromSecretKey('<your signing key>'));
    let registryContract = await tezos.contract.at('KT1JJbWfW8CHUY95hG9iq2CEMma1RiKhMHDR', tzip16);
    
    // resolve alice.edo and print out
    const name = 'alice.edo';
    let views = await registryContract.tzip16().metadataViews();
    let resolved = await views['resolve-name']().executeView(encodeString(name))
    if (resolved) {
        console.log(`${name} resolves to ${resolved.address} and expires at ${resolved.expiry}`);
    } else {
        console.log(`${name} has no valid resolution`);
    }
})().catch(e => console.error(e));
