import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create a DCA plan",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall(
                'dca-manager',
                'create-plan',
                [
                    types.uint(50_000000), // 50 USDCx
                    types.uint(144),        // 1 day (144 blocks)
                ],
                wallet1.address
            )
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        // Check plan was created
        let getPlan = chain.callReadOnlyFn(
            'dca-manager',
            'get-plan',
            [types.uint(1)],
            wallet1.address
        );
        
        console.log(getPlan.result);
    },
});

Clarinet.test({
    name: "Cannot execute plan too early",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create plan
        let block = chain.mineBlock([
            Tx.contractCall(
                'dca-manager',
                'create-plan',
                [types.uint(50_000000), types.uint(144)],
                wallet1.address
            )
        ]);
        
        // Try to execute immediately (should fail)
        block = chain.mineBlock([
            Tx.contractCall(
                'dca-manager',
                'execute-purchase',
                [types.uint(1)],
                wallet1.address
            )
        ]);
        
        block.receipts[0].result.expectErr(types.uint(102)); // ERR-TOO-EARLY
    },
});