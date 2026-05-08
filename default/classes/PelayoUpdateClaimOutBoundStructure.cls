/**
 * @description       : 
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 18-03-2026
 * @last modified by  : Daniel Flores
**/

public class PelayoUpdateClaimOutBoundStructure {

    public class UpdateClaimRequest {
        public String idSiniestroElba;
        public String idSiniestroAseguradora;
        public ClaimUpdate siniestro;
    }

    public class ClaimUpdate {
        public String cuadranteExponencial;
        public String referenciaSiniestroAseguradora;
        public String descripcionSiniestro;
        public String descripcionDeclarante;
        public String nombreDeclarante;
        public String cuestionario;
        public Date fechaDeclaracion;
        public Date fechaOcurrencia;
        public String identificadorCausa;
        public String identificadorSubcausa;
        public String identificadorTipoSiniestro;
        public String tipoSituacion;
        public Boolean urgente;
        public Boolean organoVitalAfectado;
        public Boolean servicioAsistencia;
        public Decimal provisionActual;
        public Decimal franquicia;
        public Decimal franquiciaConsumida;
        public String tramitadorElba;
        public String nombreTramitador;
        public String emailTramitador;

        public AseguradoInfo asegurado;
        public List<ContactoInfo> contactos;
        public List<GarantiaSiniestro> garantiasSiniestro;
        public List<String> danosOcasionados;
        public List<Marcador> marcadores;
        public List<Implicado> implicados;
    }

    public class AseguradoInfo {
        public String nombre;
        public String nif;
        public String movil;
        public String email;
        public Boolean quiereSMS;
        public Boolean quiereEmail;
        public Boolean admiteWhatsapp;
    }

    public class ContactoInfo {
        public String nombrePersonaContacto;
        public String parentescoAsegurado;
        public String observaciones;
        public String emailContacto;
        public List<TelefonoContacto> telefonos;
    }

    public class TelefonoContacto {
        public String numero;
        public String prioridad;
        public String horario;
    }

    public class GarantiaSiniestro {
        public String garantia;
        public String cobertura;
    }

    public class Marcador {
        public String codigo;
        public String descripcion;
    }

    public class Implicado {
        public String identificador;
        public String tipoIdentificador;
        public String nombre;
        public String apellido1;
        public String apellido2;
        public String tipoImplicado;
        public Boolean esCompaniaCausante;
        public String identificadorCompaniaAseguradora;
        public String descripcionCompaniaAseguradora;
        public String referenciaSiniestroCompaniaContraria;
        public String numeroAsegurado;
        public Date fechaBaja;
        public String comentarios;
        public String email;
        public String movilPrincipal;
        public String movilSecundario;
        public String telefonoFijo;
        public String horaInicioContactoMovilPrincipal;
        public String horaFinContactoMovilPrincipal;
        public String horaInicioContactoMovilSecundario;
        public String horaFinContactoMovilSecundario;
        public String horaInicioContactoFijo;
        public String horaFinContactoFijo;
        public DireccionImplicado direccion;
    }

    public class DireccionImplicado {
        public String tipoVia;
        public String nombreVia;
        public String numero;
        public String piso;
        public String escalera;
        public String letra;
        public String codigoPostal;
        public String poblacion;
        public String provincia;
        public String pais;
    }

    public class UpdateClaimResponse {
        public String id;
        public Boolean success;
        public String message;
        public String errors;
        public String idSiniestroElba;
        public String idSiniestroAseguradora;
    }

    /**
     * @description Builds the updateClaim JSON payload from a Case (siniestro) and related records.
     * @author Daniel Flores | 05-03-2026
     * @param caseId
     * @return String
     **/
    public static String createJSONFromCase(Id caseId) {
        if (caseId == null) {
            return null;
        }

        Case c = [
            SELECT
                Id,
                CaseNumber,
                Subject,
                InsurerClaimReference__c,
                ExponentialQuadrant__c,
                ClaimantDescription__c,
                ClaimantName__c,
                QuestionnaireComments__c,
                IncidentDate__c,
                ClaimDate__c,
                Reason__c,
                SubReason__c,
                ClaimTypeIdentifier__c,
                SituationType__c,
                Urgent__c,
                VitalOrganAffected__c,
                AssistanceService__c,
                CurrentProvisionAmount__c,
                Deductible__c,
                DeductibleUsed__c,
                DamagesIncurred__c,
                Marcadores__c,
                WantsSMSNotifications__c,
                WantsEmailNotifications__c,
                WantsWhatsAppNotifications__c,
                ClaimsHandlerName__c,
                ClaimsHandlerEmail__c,
                ContactId,
                Contact.FirstName,
                Contact.MiddleName,
                Contact.LastName,
                Contact.IDNumber__c,
                Contact.Email,
                Contact.MobilePhone
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        List<Stakeholders__c> stakeholders = [
            SELECT
                StakeholderTaxID__c,
                IdentifierType__c,
                Name,
                StakeholderType__c,
                Comments__c,
                Email__c,
                PrimaryMobile__c,
                SecondaryMobile__c,
                Phone__c,
                PrimaryMobileContactStartTime__c,
                PrimaryMobileContactEndTime__c,
                SecondaryMobileContactStartTime__c,
                SecondaryMobileContactEndTime__c,
                PhoneContactStartTime__c,
                PhoneContactEndTime__c,
                StreetType__c,
                Address__Street__s,
                StreetNumber__c,
                Floor__c,
                BuildingStar__c,
                Letter__c,
                Address__PostalCode__s,
                Address__City__s,
                Address__StateCode__s,
                Address__CountryCode__s,
                InsuranceCompanyIdentifier__c,
                InsuranceCompanyDescription__c,
                OpposingInsuranceClaimReference__c,
                PolicyholderNumber__c
            FROM Stakeholders__c
            WHERE Case__c = :caseId
        ];

        List<InsurableCoverage__c> insurableCoverages = [
            SELECT Name, Coverage__c
            FROM InsurableCoverage__c
            WHERE Claim__c = :caseId
        ];

        UpdateClaimRequest req = buildRequestFromCase(c, c.ContactId != null ? c.Contact : null, stakeholders, insurableCoverages);
        return JSON.serialize(req);
    }

    /**
     * @description Builds the updateClaim JSON payloads from a set of Cases and related records in bulk.
     * @author Daniel Flores | 05-03-2026
     * @param caseIds
     * @return Map<Id, String>
     **/
    public static Map<Id, String> createJSONFromCases(Set<Id> caseIds) {
        Map<Id, String> out = new Map<Id, String>();
        if (caseIds == null || caseIds.isEmpty()) {
            return out;
        }

        Map<Id, Case> casesById = new Map<Id, Case>([
            SELECT
                Id,
                CaseNumber,
                Subject,
                InsurerClaimReference__c,
                ExponentialQuadrant__c,
                ClaimantDescription__c,
                ClaimantName__c,
                QuestionnaireComments__c,
                IncidentDate__c,
                ClaimDate__c,
                Reason__c,
                SubReason__c,
                ClaimTypeIdentifier__c,
                SituationType__c,
                Urgent__c,
                VitalOrganAffected__c,
                AssistanceService__c,
                CurrentProvisionAmount__c,
                Deductible__c,
                DeductibleUsed__c,
                DamagesIncurred__c,
                Marcadores__c,
                WantsSMSNotifications__c,
                WantsEmailNotifications__c,
                WantsWhatsAppNotifications__c,
                ClaimsHandlerName__c,
                ClaimsHandlerEmail__c,
                ContactId,
                Contact.FirstName,
                Contact.MiddleName,
                Contact.LastName,
                Contact.IDNumber__c,
                Contact.Email,
                Contact.MobilePhone
            FROM Case
            WHERE Id IN :caseIds
        ]);

        Map<Id, List<Stakeholders__c>> stakeholdersByCaseId = new Map<Id, List<Stakeholders__c>>();
        for (Stakeholders__c s : [
            SELECT
                Case__c,
                StakeholderTaxID__c,
                IdentifierType__c,
                Name,
                StakeholderType__c,
                Comments__c,
                Email__c,
                PrimaryMobile__c,
                SecondaryMobile__c,
                Phone__c,
                PrimaryMobileContactStartTime__c,
                PrimaryMobileContactEndTime__c,
                SecondaryMobileContactStartTime__c,
                SecondaryMobileContactEndTime__c,
                PhoneContactStartTime__c,
                PhoneContactEndTime__c,
                StreetType__c,
                Address__Street__s,
                StreetNumber__c,
                Floor__c,
                BuildingStar__c,
                Letter__c,
                Address__PostalCode__s,
                Address__City__s,
                Address__StateCode__s,
                Address__CountryCode__s,
                InsuranceCompanyIdentifier__c,
                InsuranceCompanyDescription__c,
                OpposingInsuranceClaimReference__c,
                PolicyholderNumber__c
            FROM Stakeholders__c
            WHERE Case__c IN :caseIds
        ]) {
            if (s.Case__c == null) continue;
            if (!stakeholdersByCaseId.containsKey(s.Case__c)) {
                stakeholdersByCaseId.put(s.Case__c, new List<Stakeholders__c>());
            }
            stakeholdersByCaseId.get(s.Case__c).add(s);
        }

        Map<Id, List<InsurableCoverage__c>> coveragesByCaseId = new Map<Id, List<InsurableCoverage__c>>();
        for (InsurableCoverage__c cov : [
            SELECT Claim__c, Name, Coverage__c
            FROM InsurableCoverage__c
            WHERE Claim__c IN :caseIds
        ]) {
            if (cov.Claim__c == null) continue;
            if (!coveragesByCaseId.containsKey(cov.Claim__c)) {
                coveragesByCaseId.put(cov.Claim__c, new List<InsurableCoverage__c>());
            }
            coveragesByCaseId.get(cov.Claim__c).add(cov);
        }

        for (Id caseId : casesById.keySet()) {
            Case c = casesById.get(caseId);
            List<Stakeholders__c> stakeholders = stakeholdersByCaseId.containsKey(caseId)
                ? stakeholdersByCaseId.get(caseId)
                : new List<Stakeholders__c>();
            List<InsurableCoverage__c> insurableCoverages = coveragesByCaseId.containsKey(caseId)
                ? coveragesByCaseId.get(caseId)
                : new List<InsurableCoverage__c>();
            UpdateClaimRequest req = buildRequestFromCase(c, c != null && c.ContactId != null ? c.Contact : null, stakeholders, insurableCoverages);
            out.put(caseId, JSON.serialize(req));
        }

        return out;
    }

    /**
     * @description Builds the UpdateClaimRequest object from Case and related records.
     * @author Daniel Flores | 05-03-2026
     * @param c
     * @param insured
     * @param stakeholders
     * @param insurableCoverages
     * @return UpdateClaimRequest
     **/
    public static UpdateClaimRequest buildRequestFromCase(
        Case c,
        Contact insured,
        List<Stakeholders__c> stakeholders,
        List<InsurableCoverage__c> insurableCoverages
    ) {
        if (c == null) {
            return null;
        }

        UpdateClaimRequest req = new UpdateClaimRequest();
        req.idSiniestroElba = c.CaseNumber;
        req.idSiniestroAseguradora = c.InsurerClaimReference__c;

        ClaimUpdate sin = new ClaimUpdate();
        sin.cuadranteExponencial = c.ExponentialQuadrant__c;
        sin.referenciaSiniestroAseguradora = c.InsurerClaimReference__c;
        sin.descripcionSiniestro = c.Subject;
        sin.descripcionDeclarante = c.ClaimantDescription__c;
        sin.nombreDeclarante = c.ClaimantName__c;
        sin.cuestionario = c.QuestionnaireComments__c;
        sin.fechaDeclaracion = c.IncidentDate__c;
        sin.fechaOcurrencia = c.ClaimDate__c;
        sin.identificadorCausa = c.Reason__c;
        sin.identificadorSubcausa = c.SubReason__c;
        sin.identificadorTipoSiniestro = c.ClaimTypeIdentifier__c;
        sin.tipoSituacion = c.SituationType__c;
        sin.urgente = c.Urgent__c;
        sin.organoVitalAfectado = c.VitalOrganAffected__c;
        sin.servicioAsistencia = c.AssistanceService__c;
        sin.provisionActual = c.CurrentProvisionAmount__c;
        sin.franquicia = c.Deductible__c;
        sin.franquiciaConsumida = c.DeductibleUsed__c;

        // Best-effort mapping (available fields in current SF model)
        sin.nombreTramitador = c.ClaimsHandlerName__c;
        sin.emailTramitador = c.ClaimsHandlerEmail__c;

        if (insured != null) {
            AseguradoInfo a = new AseguradoInfo();
            a.nombre = joinName(insured.FirstName, insured.MiddleName, insured.LastName);
            a.nif = insured.IDNumber__c;
            a.movil = insured.MobilePhone;
            a.email = insured.Email;
            a.quiereSMS = c.WantsSMSNotifications__c;
            a.quiereEmail = c.WantsEmailNotifications__c;
            a.admiteWhatsapp = c.WantsWhatsAppNotifications__c;
            sin.asegurado = a;
        }

        List<String> danos = splitTokens(c.DamagesIncurred__c);
        if (!danos.isEmpty()) {
            sin.danosOcasionados = danos;
        }

        List<Marcador> marcadores = buildMarcadoresFromTokens(c.Marcadores__c);
        if (!marcadores.isEmpty()) {
            sin.marcadores = marcadores;
        }

        List<GarantiaSiniestro> garantias = buildGarantiasFromCoverages(insurableCoverages);
        if (!garantias.isEmpty()) {
            sin.garantiasSiniestro = garantias;
        }

        List<Implicado> implicados = buildImplicadosFromStakeholders(stakeholders);
        if (!implicados.isEmpty()) {
            sin.implicados = implicados;
        }

        req.siniestro = sin;
        return req;
    }

    private static List<GarantiaSiniestro> buildGarantiasFromCoverages(List<InsurableCoverage__c> insurableCoverages) {
        List<GarantiaSiniestro> out = new List<GarantiaSiniestro>();
        if (insurableCoverages == null) {
            return out;
        }
        for (InsurableCoverage__c cov : insurableCoverages) {
            if (cov == null) continue;
            if (String.isBlank(cov.Name) && String.isBlank(cov.Coverage__c)) continue;
            GarantiaSiniestro g = new GarantiaSiniestro();
            g.garantia = cov.Name;
            g.cobertura = cov.Coverage__c;
            out.add(g);
        }
        return out;
    }

    private static List<Marcador> buildMarcadoresFromTokens(String raw) {
        List<Marcador> out = new List<Marcador>();
        List<String> tokens = splitTokens(raw);
        for (String t : tokens) {
            if (String.isBlank(t)) continue;
            Marcador m = new Marcador();
            m.codigo = t;
            out.add(m);
        }
        return out;
    }

    private static List<Implicado> buildImplicadosFromStakeholders(List<Stakeholders__c> stakeholders) {
        List<Implicado> out = new List<Implicado>();
        if (stakeholders == null) {
            return out;
        }
        for (Stakeholders__c s : stakeholders) {
            if (s == null) continue;

            Implicado i = new Implicado();
            i.identificador = s.StakeholderTaxID__c;
            i.tipoIdentificador = s.IdentifierType__c;
            i.tipoImplicado = s.StakeholderType__c;
            i.comentarios = s.Comments__c;
            i.email = s.Email__c;
            i.movilPrincipal = s.PrimaryMobile__c;
            i.movilSecundario = s.SecondaryMobile__c;
            i.telefonoFijo = s.Phone__c;

            i.identificadorCompaniaAseguradora = s.InsuranceCompanyIdentifier__c;
            i.descripcionCompaniaAseguradora = s.InsuranceCompanyDescription__c;
            i.referenciaSiniestroCompaniaContraria = s.OpposingInsuranceClaimReference__c;
            i.numeroAsegurado = s.PolicyholderNumber__c;

            i.horaInicioContactoMovilPrincipal = formatTime(s.PrimaryMobileContactStartTime__c);
            i.horaFinContactoMovilPrincipal = formatTime(s.PrimaryMobileContactEndTime__c);
            i.horaInicioContactoMovilSecundario = formatTime(s.SecondaryMobileContactStartTime__c);
            i.horaFinContactoMovilSecundario = formatTime(s.SecondaryMobileContactEndTime__c);
            i.horaInicioContactoFijo = formatTime(s.PhoneContactStartTime__c);
            i.horaFinContactoFijo = formatTime(s.PhoneContactEndTime__c);

            if (!String.isBlank(s.Name)) {
                List<String> nameParts = s.Name.trim().split('\\s+');
                if (nameParts.size() == 1) {
                    i.nombre = nameParts[0];
                } else if (nameParts.size() == 2) {
                    i.nombre = nameParts[0];
                    i.apellido1 = nameParts[1];
                } else if (nameParts.size() >= 3) {
                    i.nombre = nameParts[0];
                    i.apellido1 = nameParts[1];
                    /* i.apellido2 = String.join(nameParts.subList(2, nameParts.size()), ' '); */
                }
            }

            DireccionImplicado d = new DireccionImplicado();
            d.tipoVia = s.StreetType__c;
            d.nombreVia = s.Address__Street__s;
            d.numero = s.StreetNumber__c;
            d.piso = s.Floor__c;
            d.escalera = s.BuildingStar__c;
            d.letra = s.Letter__c;
            d.codigoPostal = s.Address__PostalCode__s;
            d.poblacion = s.Address__City__s;
            d.provincia = s.Address__StateCode__s;
            d.pais = s.Address__CountryCode__s;

            if (!isDireccionEmpty(d)) {
                i.direccion = d;
            }

            out.add(i);
        }
        return out;
    }

    private static Boolean isDireccionEmpty(DireccionImplicado d) {
        if (d == null) return true;
        return String.isBlank(d.tipoVia) &&
            String.isBlank(d.nombreVia) &&
            String.isBlank(d.numero) &&
            String.isBlank(d.piso) &&
            String.isBlank(d.escalera) &&
            String.isBlank(d.letra) &&
            String.isBlank(d.codigoPostal) &&
            String.isBlank(d.poblacion) &&
            String.isBlank(d.provincia) &&
            String.isBlank(d.pais);
    }

    private static String joinName(String firstName, String middleName, String lastName) {
        List<String> parts = new List<String>();
        if (!String.isBlank(firstName)) parts.add(firstName.trim());
        if (!String.isBlank(middleName)) parts.add(middleName.trim());
        if (!String.isBlank(lastName)) parts.add(lastName.trim());
        return parts.isEmpty() ? null : String.join(parts, ' ');
    }

    private static String formatTime(Time t) {
        if (t == null) return null;
        String hh = String.valueOf(t.hour());
        if (hh.length() == 1) hh = '0' + hh;
        String mm = String.valueOf(t.minute());
        if (mm.length() == 1) mm = '0' + mm;
        return hh + ':' + mm;
    }

    private static List<String> splitTokens(String raw) {
        List<String> out = new List<String>();
        if (String.isBlank(raw)) {
            return out;
        }
        String normalized = raw.replace(',', ';');
        Set<String> seen = new Set<String>();
        for (String part : normalized.split(';')) {
            if (String.isBlank(part)) continue;
            String token = part.trim();
            if (String.isBlank(token)) continue;
            if (seen.contains(token)) continue;
            seen.add(token);
            out.add(token);
        }
        return out;
    }
}