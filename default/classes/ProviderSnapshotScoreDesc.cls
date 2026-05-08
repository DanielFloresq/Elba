// Comparador para ordenar ProviderSnapshot por score decrescente
public class ProviderSnapshotScoreDesc implements System.Comparator<Object> {
    public Integer compare(Object a, Object b) {
        ProviderAssignmentEngine.ProviderSnapshot pa = (ProviderAssignmentEngine.ProviderSnapshot)a;
        ProviderAssignmentEngine.ProviderSnapshot pb = (ProviderAssignmentEngine.ProviderSnapshot)b;
        if (pa.score == pb.score) return 0;
        return pa.score > pb.score ? -1 : 1;
    }
}