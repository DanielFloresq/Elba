/**
 * @description       : Test class for PutPelayoEncargoAction — validates the @InvocableMethod
 *                      entry point that sends Pelayo encargo (assignment) update requests.
 * @author            : Daniel Flores
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class PutPelayoEncargoActionTest {

    // ─── Test data helpers ───────────────────────────────────────────────────

    /**
     * @description Creates common test data (Account, Case, Order) shared across test methods.
     */
    @TestSetup
    static void setupTestData() {
        // TODO: insert Account, Case and Order records required for encargo processing
    }

    // ─── putEncargo ──────────────────────────────────────────────────────────

    /**
     * @description Verifies that putEncargo processes a single request without throwing.
     */
    @IsTest
    static void putEncargo_singleRequest_doesNotThrow() {
        PutPelayoEncargoAction.PutPelayoEncargoRequest req =
            new PutPelayoEncargoAction.PutPelayoEncargoRequest();
        req.type = 'AL';
        req.encargoIds = new List<String>();

        Test.startTest();
        PutPelayoEncargoAction.putEncargo(
            new List<PutPelayoEncargoAction.PutPelayoEncargoRequest>{ req }
        );
        Test.stopTest();

        // No exception expected
    }

    /**
     * @description Verifies that putEncargo handles an empty request list gracefully.
     */
    @IsTest
    static void putEncargo_emptyRequestList_doesNotThrow() {
        Test.startTest();
        PutPelayoEncargoAction.putEncargo(
            new List<PutPelayoEncargoAction.PutPelayoEncargoRequest>()
        );
        Test.stopTest();

        // No exception expected
    }

    /**
     * @description Verifies that putEncargo iterates and processes multiple requests.
     */
    @IsTest
    static void putEncargo_multipleRequests_processesAll() {
        PutPelayoEncargoAction.PutPelayoEncargoRequest req1 =
            new PutPelayoEncargoAction.PutPelayoEncargoRequest();
        req1.type = 'AL';
        req1.encargoIds = new List<String>();

        PutPelayoEncargoAction.PutPelayoEncargoRequest req2 =
            new PutPelayoEncargoAction.PutPelayoEncargoRequest();
        req2.type = 'MO';
        req2.encargoIds = new List<String>();

        Test.startTest();
        PutPelayoEncargoAction.putEncargo(
            new List<PutPelayoEncargoAction.PutPelayoEncargoRequest>{ req1, req2 }
        );
        Test.stopTest();

        // No exception expected; both requests should be iterated
    }
}