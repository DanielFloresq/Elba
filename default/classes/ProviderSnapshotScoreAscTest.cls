/**
 * @description       : Test class for ProviderSnapshotScoreAsc — validates ascending score
 *                      comparison of ProviderSnapshot objects via the Comparator interface.
 * @author            : Test Class Builder
 * @group             : Provider Assignment
**/
@IsTest
private class ProviderSnapshotScoreAscTest {

    private static ProviderAssignmentEngine.ProviderSnapshot snap(Decimal score) {
        ProviderAssignmentEngine.ProviderSnapshot s = new ProviderAssignmentEngine.ProviderSnapshot(new Account(Name = 'Test'));
        s.score = score;
        return s;
    }

    @IsTest
    static void compare_firstLower_returnsNegative() {
        ProviderSnapshotScoreAsc comparator = new ProviderSnapshotScoreAsc();
        ProviderAssignmentEngine.ProviderSnapshot a = snap(10);
        ProviderAssignmentEngine.ProviderSnapshot b = snap(20);

        Test.startTest();
        Integer result = comparator.compare(a, b);
        Test.stopTest();

        System.assert(result < 0,
            'Lower score must sort first in ascending order. Got: ' + result);
    }

    @IsTest
    static void compare_firstHigher_returnsPositive() {
        ProviderSnapshotScoreAsc comparator = new ProviderSnapshotScoreAsc();
        ProviderAssignmentEngine.ProviderSnapshot a = snap(50);
        ProviderAssignmentEngine.ProviderSnapshot b = snap(20);

        Test.startTest();
        Integer result = comparator.compare(a, b);
        Test.stopTest();

        System.assert(result > 0,
            'Higher score must sort after lower score in ascending order. Got: ' + result);
    }

    @IsTest
    static void compare_equalScores_returnsZero() {
        ProviderSnapshotScoreAsc comparator = new ProviderSnapshotScoreAsc();
        ProviderAssignmentEngine.ProviderSnapshot a = snap(33.5);
        ProviderAssignmentEngine.ProviderSnapshot b = snap(33.5);

        Test.startTest();
        Integer result = comparator.compare(a, b);
        Test.stopTest();

        System.assertEquals(0, result, 'Equal scores must return zero');
    }

    @IsTest
    static void compare_listSort_orderIsAscending() {
        ProviderAssignmentEngine.ProviderSnapshot a = snap(30);
        ProviderAssignmentEngine.ProviderSnapshot b = snap(10);
        ProviderAssignmentEngine.ProviderSnapshot c = snap(20);

        List<ProviderAssignmentEngine.ProviderSnapshot> bag =
            new List<ProviderAssignmentEngine.ProviderSnapshot>{ a, b, c };

        Test.startTest();
        bag.sort(new ProviderSnapshotScoreAsc());
        Test.stopTest();

        System.assertEquals(10, bag[0].score, 'Lowest score should be first');
        System.assertEquals(20, bag[1].score, 'Middle score should be second');
        System.assertEquals(30, bag[2].score, 'Highest score should be last');
    }
}
