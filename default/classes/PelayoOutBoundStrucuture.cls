/**
 * @description       : Base outbound structure builder for Pelayo API JSON payloads
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 20-04-2026
 * @last modified by  : Daniel Flores
**/
public class PelayoOutBoundStrucuture {

    private static final String SUPPLIER_RECORD_TYPE = 'Supplier';

    public String idSiniestroElba;
    public String idSiniestroAseguradora;
    public String movimiento;
    public List<Encargo> encargos;

    public class Encargo {
        public String idEncargoElba;
        public String idEncargoAseguradora;
        public Date fechaEncargo;
        public Time horaEncargo;
        public String tramitadorEncargo;
        public String tipo;
        public String tipoProveedor;
        public String gremio;
        public String estado;
        public String observaciones;
        public Boolean urgente;
        public Proveedor proveedor;
        public List<Servicio> servicios;
    }

    public class Proveedor {
        public String id;
        public String nombre;
        public String email;
        public String telefono;
        public String movil;
    }

    public class Servicio {
        public String idServicio;
        public String estado;
        public String gremio;
        public String implicado;
        public String situacion;
        public String descripcion;
        public Date fechaApertura;
    }

    /*************************************** */

    public class CaseInfo {
        public String caseNumber;
        public String insurerClaimReference;
        public String claimsHandlerName;
    }

    /**
     * @description Builds the JSON payload for the Pelayo updateAssignment API from Case info, Orders, provider account data, and a movement type.
     * @param caseInfo Wrapper with Case-level identifiers.
     * @param listEncargo List of Order records (encargos) to include.
     * @param mapAccountInformation Map of provider account phone/email values keyed by Type_AccountId.
     * @param type The movement type identifier (e.g. 'AL', 'MO').
     * @return Serialized JSON string of the outbound payload.
     */
    public static String createJSON(CaseInfo caseInfo, List<Order> listEncargo, Map<String, String> mapAccountInformation, String type){

        PelayoOutBoundStrucuture body = new PelayoOutBoundStrucuture();
        body.idSiniestroElba = caseInfo.caseNumber;
        body.idSiniestroAseguradora = caseInfo.insurerClaimReference;
        body.movimiento = type;

        body.encargos = new List<Encargo>();

        for (Order encargo : listEncargo) {
            Encargo encargoBody = new Encargo();
            encargoBody.idEncargoElba = encargo.Id;
            encargoBody.idEncargoAseguradora = encargo.ChargeIdentifier__c;
            encargoBody.fechaEncargo = encargo.EffectiveDate;
            encargoBody.horaEncargo = encargo.CreatedDate.time();
            encargoBody.tramitadorEncargo = caseInfo.claimsHandlerName;
            encargoBody.tipo = encargo.Type;
            encargoBody.tipoProveedor = encargo.ProviderType__c;
            encargoBody.gremio = encargo.Guild__c;
            encargoBody.estado = encargo.Status;
            encargoBody.observaciones = encargo.Observaciones__c;
            encargoBody.urgente = encargo.Urgent__c;

            if(type != null && isSupplierOrder(encargo)) {
                Proveedor proveedorBody = new Proveedor();
                proveedorBody.id = encargo.Account.SAPEntityCode__c;
                proveedorBody.nombre = encargo.Account.Name;
                proveedorBody.email = mapAccountInformation.containsKey('Email_' + encargo.AccountId) ? mapAccountInformation.get('Email_' + encargo.AccountId) : null;
                proveedorBody.telefono = encargo.Account.Phone;
                proveedorBody.movil = mapAccountInformation.containsKey('Phone_' + encargo.AccountId) ? mapAccountInformation.get('Phone_' + encargo.AccountId) : null;
                encargoBody.proveedor = proveedorBody;
            }

            List<Servicio> listaServiciosBody = new List<Servicio>();
            for (Service__c service : encargo.Services__r) {
                Servicio servicioBody = new Servicio();
                servicioBody.idServicio = service.Name;
                servicioBody.estado = service.Status__c;
                servicioBody.gremio = service.Type__c;
                servicioBody.implicado = service.Stakeholder__r.Name;
                servicioBody.situacion = service.Status__c;
                servicioBody.descripcion = service.Description__c;
                servicioBody.fechaApertura = service.StartDate__c;
                listaServiciosBody.add(servicioBody);
            }
            encargoBody.servicios = listaServiciosBody;
            body.encargos.add(encargoBody);
        }
        return JSON.serialize(body);
    }

    /**
     * @description Queries AccountInformation__c records for the providers referenced in the given Orders and returns a map keyed by Type_AccountId.
     * @param listEncargo List of Order records whose AccountIds are used to query provider information.
     * @return Map of account information values keyed by 'Type_AccountId'.
     */
    public static Map<String, String> setMapAccountInformation(List<Order> listEncargo) {
        List<String> listProviderIds = new List<String>();
        for (Order encargo : listEncargo) {
            if (isSupplierOrder(encargo) && encargo.AccountId != null) {
                listProviderIds.add(encargo.AccountId);
            }
        }

        Map<String, String> accountInformationMap = new Map<String, String>();
        List<AccountInformation__c> listAccountInformation = [SELECT Id, Type__c, Value__c, Account__c FROM AccountInformation__c WHERE Account__c IN :listProviderIds];
        for (AccountInformation__c accountInfo : listAccountInformation) {
            accountInformationMap.put(accountInfo.Type__c + '_' + accountInfo.Account__c, accountInfo.Value__c);
        }
        return accountInformationMap;
    }

    private static Boolean isSupplierOrder(Order encargo) {
        return encargo != null
            && encargo.Account != null
            && encargo.Account.RecordType != null
            && encargo.Account.RecordType.DeveloperName == SUPPLIER_RECORD_TYPE;
    }
}