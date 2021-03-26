const { InMemorySigner } = require('@taquito/signer');
const { TezosToolkit } = require('@taquito/taquito');
const { Tzip16Module, tzip16 } = require('@taquito/tzip16');

/**
 * Converts bytes in hexadecimal format to string (using UTF-8).
 * 
 * @param {string} str input string containing bytes in hexadecimal format
 * @returns string the decoded string
 */
function decodeString(hexString) {
    return new TextDecoder().decode(new Uint8Array(hexString.match(/.{1,2}/g)?.map(byte => parseInt(byte, 16)) || []));
}

(async () => {
    // create a contract instance equipped to handle tzip-16 calls
    const tezos = new TezosToolkit('https://edonet.smartpy.io/');
    tezos.addExtension(new Tzip16Module());
    tezos.setSignerProvider(await InMemorySigner.fromSecretKey('<your signing key>'));
    let registryContract = await tezos.contract.at('KT1JJbWfW8CHUY95hG9iq2CEMma1RiKhMHDR', tzip16);
    
    // resolve an address and print out
    const address = 'tz1VBLpuDKMoJuHRLZ4HrCgRuiLpEr7zZx2E';
    let views = await registryContract.tzip16().metadataViews();
    let resolved = await views['resolve-address']().executeView(address);
    if (resolved) {
        console.log(`${address} resolves to ${decodeString(resolved.name)}, which expires at ${resolved.expiry}`);
    } else {
        console.log(`${address} has no valid resolution`);
    }
})().catch(e => console.error(e));
