/**
 * @description       : Test class for ProviderSnapshotScoreDesc — validates descending score
 *                      comparison of ProviderSnapshot objects via the Comparator interface.
 * @author            : Daniel Flores
 * @last modified on  : 14-01-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
private class ProviderSnapshotScoreDescTest {

    // ─── compare ─────────────────────────────────────────────────────────────

    /**
     * @description Verifies that compare returns a positive value when the first snapshot
     *              has a lower score than the second (descending order).
     */
    @IsTest
    static void compare_firstLower_returnsPositive() {
        ProviderSnapshotScoreDesc comparator = new ProviderSnapshotScoreDesc();

        // TODO: create two ProviderAssignmentEngine.ProviderSnapshot instances
        //       with different scores (a.score < b.score)
        Test.startTest();
        // Integer result = comparator.compare(snapshotA, snapshotB);
        Test.stopTest();

        // System.assert(result > 0, 'Lower score should sort after higher score in descending order');
    }

    /**
     * @description Verifies that compare returns a negative value when the first snapshot
     *              has a higher score than the second (descending order).
     */
    @IsTest
    static void compare_firstHigher_returnsNegative() {
        ProviderSnapshotScoreDesc comparator = new ProviderSnapshotScoreDesc();

        // TODO: create two ProviderAssignmentEngine.ProviderSnapshot instances
        //       with different scores (a.score > b.score)
        Test.startTest();
        // Integer result = comparator.compare(snapshotA, snapshotB);
        Test.stopTest();

        // System.assert(result < 0, 'Higher score should sort before lower score in descending order');
    }

    /**
     * @description Verifies that compare returns zero when both snapshots have equal scores.
     */
    @IsTest
    static void compare_equalScores_returnsZero() {
        ProviderSnapshotScoreDesc comparator = new ProviderSnapshotScoreDesc();

        // TODO: create two ProviderAssignmentEngine.ProviderSnapshot instances
        //       with the same score
        Test.startTest();
        // Integer result = comparator.compare(snapshotA, snapshotB);
        Test.stopTest();

        // System.assertEquals(0, result, 'Equal scores should return zero');
    }
}