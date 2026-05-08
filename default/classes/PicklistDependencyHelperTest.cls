/**
 * @description       : Test class for PicklistDependencyHelper.
 *                      Covers getDependentValues with valid + invalid object names,
 *                      getDependentValuesForControlling lookup, exception swallow path,
 *                      and contract: returns a populated PicklistInfo even when no
 *                      dependency is configured (fallback returns all active values).
 * @author            : Test Class Builder
 * @group             : Utilities
**/
@IsTest
private class PicklistDependencyHelperTest {

    // ─── getDependentValues — happy path ─────────────────────────────────────

    @IsTest
    static void getDependentValues_onCase_returnsControllingValues() {
        // Case has restricted picklists like Status, Priority, Origin — Status is always present.
        Test.startTest();
        PicklistDependencyHelper.PicklistInfo info =
            PicklistDependencyHelper.getDependentValues('Case', 'Status', 'Origin');
        Test.stopTest();

        System.assertNotEquals(null, info, 'Result should never be null');
        System.assertNotEquals(null, info.allControllingValues,
            'allControllingValues should be initialised');
        System.assert(!info.allControllingValues.isEmpty(),
            'Case.Status has multiple values — allControllingValues should not be empty');
    }

    // ─── getDependentValues — invalid object swallowed ──────────────────────

    @IsTest
    static void getDependentValues_invalidObject_returnsEmptyShape() {
        Test.startTest();
        PicklistDependencyHelper.PicklistInfo info =
            PicklistDependencyHelper.getDependentValues('NotARealObject__c', 'Bogus__c', 'Bogus__c');
        Test.stopTest();

        System.assertNotEquals(null, info,
            'Helper should swallow exceptions and still return an info instance');
        System.assertEquals(true, info.dependentValues.isEmpty(),
            'No dependentValues entries should be produced for an invalid object');
        System.assertEquals(true, info.allControllingValues.isEmpty(),
            'No controlling values should be produced for an invalid object');
    }

    @IsTest
    static void getDependentValues_invalidField_returnsEmptyShape() {
        Test.startTest();
        PicklistDependencyHelper.PicklistInfo info =
            PicklistDependencyHelper.getDependentValues('Case', 'NoSuchField__c', 'Origin');
        Test.stopTest();

        System.assertNotEquals(null, info, 'Result should never be null');
        System.assertEquals(true, info.dependentValues.isEmpty(),
            'No dependentValues for an unknown controlling field');
    }

    // ─── getDependentValuesForControlling ────────────────────────────────────

    @IsTest
    static void getDependentValuesForControlling_unknownControlling_returnsEmptyList() {
        Test.startTest();
        List<String> result = PicklistDependencyHelper.getDependentValuesForControlling(
            'Case', 'Status', 'Origin', 'ValueDoesNotExist'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result list must never be null');
        System.assertEquals(true, result.isEmpty(),
            'Unknown controlling value should yield an empty dependent list');
    }

    // ─── Fallback contract: no real dependency configured ───────────────────
    // The helper does not call getValidFor(); for every controlling value it
    // returns the full list of active dependent picklist entries. This test
    // pins that contract so a future refactor that introduces real-dependency
    // filtering will surface as a behavior change rather than silent drift.
    @IsTest
    static void getDependentValues_noConfiguredDependency_populatesAllForEveryControlling() {
        Test.startTest();
        PicklistDependencyHelper.PicklistInfo info =
            PicklistDependencyHelper.getDependentValues('Case', 'Status', 'Priority');
        Test.stopTest();

        System.assertNotEquals(null, info, 'Result should never be null');
        if (info.allControllingValues.isEmpty()) {
            // Org-specific: skip when Case.Status has no values in the running org.
            return;
        }

        // Every controlling value must map to the same set of dependent values
        // (the fallback returns all active entries regardless of the controlling key).
        List<String> firstDependentList = info.dependentValues.get(info.allControllingValues[0]);
        System.assertNotEquals(null, firstDependentList,
            'Every controlling value must have a dependentValues entry');
        for (String controlling : info.allControllingValues) {
            List<String> dependents = info.dependentValues.get(controlling);
            System.assertEquals(firstDependentList.size(), dependents.size(),
                'Fallback contract: every controlling value should map to the same number of dependents (no per-value filtering)');
        }
    }

    @IsTest
    static void getDependentValuesForControlling_validControlling_returnsList() {
        // Build the info first to discover a real controlling value
        PicklistDependencyHelper.PicklistInfo info =
            PicklistDependencyHelper.getDependentValues('Case', 'Status', 'Origin');
        if (info.allControllingValues.isEmpty()) {
            return; // org-specific: nothing to assert
        }
        String anyControlling = info.allControllingValues[0];

        Test.startTest();
        List<String> result = PicklistDependencyHelper.getDependentValuesForControlling(
            'Case', 'Status', 'Origin', anyControlling
        );
        Test.stopTest();

        System.assertNotEquals(null, result,
            'A known controlling value should yield a non-null list');
    }
}
