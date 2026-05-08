/**
 * @description       : Comparator for sorting provider snapshots by score in ascending order
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 04-02-2026
 * @last modified by  : Afonso Duque
**/
public class ProviderSnapshotScoreAsc implements System.Comparator<Object>{
    /**
     * @description Compares two ProviderSnapshot objects by score in ascending order
     * @param a First object to compare (cast to ProviderSnapshot)
     * @param b Second object to compare (cast to ProviderSnapshot)
     * @return Integer negative if a < b, 0 if equal, positive if a > b
     */
    public Integer compare(Object a, Object b) {
        ProviderAssignmentEngine.ProviderSnapshot pa = (ProviderAssignmentEngine.ProviderSnapshot)a;
        ProviderAssignmentEngine.ProviderSnapshot pb = (ProviderAssignmentEngine.ProviderSnapshot)b;
        if (pa.score == pb.score) return 0;
        return pb.score > pa.score ? -1 : 1;
    }
}