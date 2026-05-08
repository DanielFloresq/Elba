/**
 * @description       : Service class for calculating guild assignments based on order criteria
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 04-02-2026
 * @last modified by  : Daniel Flores
**/
public class GuildCalculatorService {
    
    private static final Map<String, String> REASON_API_TO_LABEL = new Map<String, String>{
        'A17' => 'Machinery Breakdown',
        'T1' => 'All-risk accidental',
        'A12' => 'Appliance breakdown',
        'L2' => 'Appliance windows',
        'A1' => 'Bodily injuries',
        'R2' => 'Civil liability',
        'C1' => 'Community',
        'C2' => 'Consortium coverage',
        'R4' => 'Damage claim/legal protection',
        'A6' => 'Domestic animals',
        'A7' => 'Electrical assistance',
        'D3' => 'Displaced Goods',
        'A13' => 'Emergency assistance',
        'I1' => 'Fire, lightning, explosion',
        'D1' => 'Garden deterioration',
        'R1' => 'Glass breakage',
        'A2' => 'Guide dog accidents',
        'M1' => 'Handyman',
        'A8' => 'Home assistance',
        'I2' => 'Impact',
        'A9' => 'IT assistance',
        'P1' => 'Lost luggage',
        'A11' => 'Mugging',
        'P2' => 'Payment protection',
        'A5' => 'Refrigerated food',
        'L1' => 'Sanitary ware',
        'R3' => 'Theft',
        'A3' => 'Vandalism Acts',
        'A10' => 'VIP assistance',
        'A4' => 'Water',
        'F1' => 'Weather events',
        'A14' => 'Hunter Accidents',
        'A15' => 'Extraordinary Assistance',
        'A16' => 'Healthcare Assistance',
        'B1' => 'Displaced Goods',
        'B2' => 'Refrigerated Goods',
        'C3' => 'Boiler',
        'D4' => 'Complementary Damages',
        'D5' => 'Electrical Damages',
        'E1' => 'Electronic Equipment',
        'F2' => 'Death',
        'H1' => 'Hospitalization',
        'H2' => 'Theft (Burglary)',
        'I3' => 'Temporary Disability',
        'I4' => 'Fire',
        'I5' => 'Permanent Disability',
        'L3' => 'Rain',
        'L4' => 'Appliance Windows, Mirrors, And Glass',
        'P3' => 'Hail / Snow',
        'P4' => 'Loss Of Benefits',
        'P5' => 'Legal Protection',
        'R5' => 'Civil Liability Activity',
        'R6' => 'Hunter And Fisherman Civil Liability',
        'R7' => 'General Civil Liability',
        'R8' => 'Employer\'s Civil Liability',
        'R9' => 'Product Civil Liability',
        'R10' => 'License Withdrawal',
        'S1' => 'Assistance Service',
        'S2' => 'Handyman Service',
        'S3' => 'Handyman Plus Service',
        'T2' => 'Stock Transport',
        'V1' => 'Wind',
        'D2' => 'Aesthetic damage'
    };
    private static final Map<String, String> REASON_LABEL_TO_ES = new Map<String, String>{
        'Machinery Breakdown' => 'Avería de Maquinaria',
        'All-risk accidental' => 'Todo riesgo accidental',
        'Appliance breakdown' => 'Avería de electrodomésticos',
        'Appliance windows' => 'Lunas de electrodomésticos',
        'Bodily injuries' => 'Accidentes corporales',
        'Civil liability' => 'Responsabilidad civil',
        'Community' => 'Comunitarios',
        'Consortium coverage' => 'Consorciable',
        'Damage claim/legal protection' => 'Reclamación de daños/protección jurídica',
        'Domestic animals' => 'Animales domésticos',
        'Electrical assistance' => 'Asistencia eléctrica',
        'Displaced Goods' => 'Bienes Desplazados',
        'Emergency assistance' => 'Asistencia (urg)',
        'Fire, lightning, explosion' => 'Incendio, rayo, explosión',
        'Garden deterioration' => 'Deterioro de jardines',
        'Glass breakage' => 'Rotura de cristales',
        'Guide dog accidents' => 'Accidentes de perros guía',
        'Handyman' => 'Manitas',
        'Home assistance' => 'Asistencia a la vivienda',
        'Impact' => 'Impacto',
        'IT assistance' => 'Asistencia informática',
        'Lost luggage' => 'Pérdida de equipaje',
        'Mugging' => 'Atraco',
        'Payment protection' => 'Protección de pagos',
        'Refrigerated food' => 'Alimentos refrigerados',
        'Sanitary ware' => 'Loza sanitaria',
        'Theft' => 'Robo',
        'Vandalism Acts' => 'Actos vandálicos',
        'VIP assistance' => 'Asistencia VIP',
        'Water' => 'Agua',
        'Weather events' => 'Fenómenos meteorológicos',
        'Hunter Accidents' => 'Accidentes Cazador',
        'Extraordinary Assistance' => 'Asistencia Extraordinaria',
        'Healthcare Assistance' => 'Asistencia Sanitaria',
        'Refrigerated Goods' => 'Bienes refrigerados',
        'Boiler' => 'Caldera',
        'Complementary Damages' => 'Daños Complementarios',
        'Electrical Damages' => 'Daños eléctricos',
        'Electronic Equipment' => 'Equipos electrónicos',
        'Death' => 'Fallecimiento',
        'Hospitalization' => 'Hospitalizacion',
        'Theft (Burglary)' => 'Hurto',
        'Temporary Disability' => 'Incapacidad Temporal',
        'Fire' => 'Incendio',
        'Permanent Disability' => 'Invalidez Permanente',
        'Rain' => 'Lluvia',
        'Appliance Windows, Mirrors, And Glass' => 'Lunas, Espejos Y Cristales',
        'Hail / Snow' => 'Pedrisco / Nieve',
        'Loss Of Benefits' => 'Perdida De Beneficios',
        'Legal Protection' => 'Protección Jurídica',
        'Civil Liability Activity' => 'Responsabilidad Civil Actividad',
        'Hunter And Fisherman Civil Liability' => 'Responsabilidad Civil Cazador Y Pescador',
        'General Civil Liability' => 'Responsabilidad Civil General',
        'Employer\'s Civil Liability' => 'Responsabilidad Civil Patronal',
        'Product Civil Liability' => 'Responsabilidad Civil Productos',
        'License Withdrawal' => 'Retirada De Carnet',
        'Assistance Service' => 'Servicio de Asistencia',
        'Handyman Service' => 'Servicio Manitas',
        'Handyman Plus Service' => 'Servicio Manitas Plus',
        'Stock Transport' => 'Transporte De Existencias',
        'Wind' => 'Viento',
        'Aesthetic damage' => 'Daños estéticos'
    };
    
    private static final Map<String, String> SUBREASON_API_TO_LABEL = new Map<String, String>{
        'A1' => 'Masonry',
        'A2' => 'Refrigerated food',
        'A3' => 'Animals',
        'A4' => 'Vision and sound devices',
        'A5' => 'Landlord /owner of the house//owner/co-owner',
        'A6' => 'Settlements or land movements due to third-party works',
        'A7' => 'Telephone advice in case of theft',
        'A8' => 'Electrical assistance (liability)',
        'A9' => 'On-site IT assistance',
        'A10' => 'Remote IT assistance',
        'A11' => 'Home technology assistance',
        'A12' => 'Appliance breakdown',
        'A13' => 'Veterinary assistance',
        'A14' => 'Guide dog veterinary assistance',
        'A15' => 'Blockages with damage',
        'A16' => 'Blockages without damage',
        'A17' => 'Mugging outside the home',
        'A18' => 'Vandalism',
        'B1' => 'Bicycles',
        'C1' => 'Boilers and heaters',
        'C2' => 'Meteorite fall',
        'C3' => 'Fall of trees, poles, and antennas',
        'C4' => 'Aircraft crash',
        'C5' => 'Lightning strike',
        'C6' => 'Emergency locksmith',
        'C7' => 'Locksmith',
        'C8' => 'Animal collision',
        'C9' => 'Vehicle collision',
        'C10' => 'Condensation',
        'C11' => 'Remote backup',
        'C12' => 'Corrosion',
        'C13' => 'Short circuit',
        'C14' => 'Appliance glass',
        'C15' => 'Furniture glass',
        'C16' => 'Door glass',
        'C17' => 'Window glass',
        'C18' => 'Glazing',
        'D1' => 'Electrical damage',
        'D2' => 'Aesthetic damage',
        'D3' => 'Garden deterioration',
        'D4' => 'Athlete',
        'D5' => 'Sports',
        'D6' => 'Spills in fire extinguishing installations (building)',
        'D7' => 'Building damage from attempted theft',
        'D8' => 'Rockfalls and avalanches',
        'E1' => 'Electricity',
        'E2' => 'Emergency electricity',
        'E3' => 'Appliances',
        'E4' => 'Kitchen countertop',
        'E5' => 'Mirror',
        'E6' => 'Water leak / isolated leak',
        'E7' => 'Appliance leak',
        'E8' => 'Shop window',
        'E9' => 'Explosion',
        'F1' => 'Death and funeral expenses (liability)',
        'F2' => 'Localized rainwater leak',
        'F3' => 'Leaks',
        'F4' => 'Leaks through roofs / covers / facades / terraces / patios',
        'F5' => 'Tile leaks',
        'F6' => 'Evident internal leaks',
        'F7' => 'Leaks in patios, terraces, or covers',
        'F8' => 'Ground leaks',
        'F9' => 'Plumbing',
        'F10' => 'Boiler leak',
        'F11' => 'Radiator/visible pipe/shut-off valve leak',
        'G1' => 'Continuous dripping',
        'H1' => 'House inhabitant',
        'H2' => 'Smoke',
        'H3' => 'Theft in the home',
        'I1' => 'Fire',
        'I2' => 'Tenant',
        'I3' => 'Employee dishonesty',
        'I4' => 'Flooding from public network',
        'I5' => 'Flooding from overflowing channels, ditches',
        'I6' => 'Permanant and total disability (liability)',
        'L1' => 'Home cleaning',
        'L2' => 'Rain',
        'M1' => 'Shower screen',
        'M2' => 'Tech handyman'/* ,
        'M3' => '...'  */
    };
    private static final Map<String, String> SUBREASON_LABEL_TO_ES = new Map<String, String>{
        'Masonry' => 'Mampostería',
        'Refrigerated food' => 'Alimentos refrigerados',
        'Animals' => 'Animales',
        'Vision and sound devices' => 'Dispositivos de visión y sonido',
        'Landlord /owner of the house//owner/co-owner' => 'Propietario/Co-propietario',
        'Settlements or land movements due to third-party works' => 'Asentamientos o movimientos de tierra por obras de terceros',
        'Telephone advice in case of theft' => 'Asesoría telefónica en caso de robo',
        'Electrical assistance (liability)' => 'Asistencia eléctrica (RC)',
        'On-site IT assistance' => 'Asistencia informática in situ',
        'Remote IT assistance' => 'Asistencia informática remota',
        'Home technology assistance' => 'Asistencia tecnología hogar',
        'Appliance breakdown' => 'Avería de electrodomésticos',
        'Veterinary assistance' => 'Asistencia veterinaria',
        'Guide dog veterinary assistance' => 'Asistencia veterinaria perro guía',
        'Blockages with damage' => 'Atascos CON daños',
        'Blockages without damage' => 'Atascos SIN daños',
        'Mugging outside the home' => 'Atraco fuera del hogar',
        'Vandalism' => 'Vandalismo',
        'Bicycles' => 'Bicicletas',
        'Boilers and heaters' => 'Calderas y calentadores',
        'Meteorite fall' => 'Caída de meteorito',
        'Fall of trees, poles, and antennas' => 'Caída de árboles, postes y antenas',
        'Aircraft crash' => 'Caida de aeronaves',
        'Lightning strike' => 'Caída de rayo',
        'Emergency locksmith' => 'Cerrajero de emergencia',
        'Locksmith' => 'Cerrajero',
        'Animal collision' => 'Choque de animales',
        'Vehicle collision' => 'Colisión de vehículo',
        'Condensation' => 'Condensaciones',
        'Remote backup' => 'Copia de seguridad remota',
        'Corrosion' => 'Corrosión',
        'Short circuit' => 'Cortocircuito',
        'Appliance glass' => 'Cristal de electroméstico',
        'Furniture glass' => 'Cristal de mueble',
        'Door glass' => 'Cristal de puerta',
        'Window glass' => 'Cristal de ventana',
        'Glazing' => 'Acristalamiento',
        'Electrical damage' => 'Daños eléctricos',
        'Aesthetic damage' => 'Daños estéticos',
        'Garden deterioration' => 'Deterioro de jardines',
        'Athlete' => 'Deportista',
        'Sports' => 'Deportes',
        'Spills in fire extinguishing installations (building)' => 'Derrames en instalaciones de extinción de incendios (edificio)',
        'Building damage from attempted theft' => 'Desperfectos continente por intento de robo',
        'Rockfalls and avalanches' => 'Desprendimientos y avalanchas',
        'Electricity' => 'Electricidad',
        'Emergency electricity' => 'Electricidad de emergencia',
        'Appliances' => 'Electrodomésticos',
        'Kitchen countertop' => 'Encimera de cocina',
        'Mirror' => 'Espejo',
        'Water leak / isolated leak' => 'Fuga de agua / fuga aislada',
        'Appliance leak' => 'Escape de electrodomésticos',
        'Shop window' => 'Escaparate',
        'Explosion' => 'Explosión',
        'Death and funeral expenses (liability)' => 'Fallecimiento y gastos funerarios (RC)',
        'Localized rainwater leak' => 'Fuga localizada de agua de lluvia',
        'Leaks' => 'Fugas',
        'Leaks through roofs / covers / facades / terraces / patios' => 'Fugas por cubiertas/terrazas/patios',
        'Tile leaks' => 'Fugas en azulejos',
        'Evident internal leaks' => 'Fugas internas evidentes',
        'Leaks in patios, terraces, or covers' => 'Fugas en patios, terrazas o cubiertas',
        'Ground leaks' => 'Fugas en el suelo',
        'Plumbing' => 'Fontanería',
        'Boiler leak' => 'Fuga caldera',
        'Radiator/visible pipe/shut-off valve leak' => 'Fuga radiador/tubería/válvula',
        'Continuous dripping' => 'Goteo continuado',
        'House inhabitant' => 'Habitante de la casa',
        'Smoke' => 'Humo',
        'Theft in the home' => 'Robo en el hogar',
        'Fire' => 'Incendio',
        'Tenant' => 'Inquilino',
        'Employee dishonesty' => 'Deshonestidad de empleado',
        'Flooding from public network' => 'Inundación por red pública',
        'Flooding from overflowing channels, ditches' => 'Inundación por desbordamiento de canales',
        'Permanant and total disability (liability)' => 'Incapacidad permanente y total (RC)',
        'Home cleaning' => 'Limpieza del hogar',
        'Rain' => 'Lluvia',
        'Shower screen' => 'Mampara de ducha',
        'Tech handyman' => 'Manitas tecnológico',
        '...' => '...'
    };
    public class GuildRequest {
        @InvocableVariable(required=true)
        public String grandAccount;
        @InvocableVariable(required=true)
        public String reason;
        
        @InvocableVariable(required=true)
        public List<String> damage;
        @InvocableVariable(required=true)
        public String subreason;
    }

    public class GuildResponse {
        @InvocableVariable
        public String guild;
    }

    /**
     * @description Calculates the guild assignment for each request based on grand account, reason, damage, and subreason using GuildCalculator__mdt custom metadata
     * @param requests List of GuildRequest wrappers containing the criteria for guild calculation
     * @return List of GuildResponse wrappers containing the calculated guild values
     */
    @InvocableMethod(label='Calcular Guild' description='Retorna o Guild para os parâmetros fornecidos.')
    public static List<GuildResponse> getGuild(List<GuildRequest> requests) {
        List<GuildResponse> responses = new List<GuildResponse>();

        Set<String> allDamages = new Set<String>();
        for (GuildRequest req : requests) {
            if (req.damage != null) {
                allDamages.addAll(req.damage);
            }
        }

        List<GuildCalculator__mdt> metadatas = [
            SELECT GrandAccount__c, Reason__c, Damage__c, Subreason__c, Guild__c
            FROM GuildCalculator__mdt
            WHERE Damage__c IN :allDamages
        ];

        for (GuildRequest req : requests) {
            
            String reasonLabel = REASON_API_TO_LABEL.containsKey(req.reason) ? REASON_API_TO_LABEL.get(req.reason) : req.reason;
            String subreasonLabel = SUBREASON_API_TO_LABEL.containsKey(req.subreason) ? SUBREASON_API_TO_LABEL.get(req.subreason) : req.subreason;

            
            String reasonEs = REASON_LABEL_TO_ES.containsKey(reasonLabel) ? REASON_LABEL_TO_ES.get(reasonLabel) : reasonLabel;
            String subreasonEs = SUBREASON_LABEL_TO_ES.containsKey(subreasonLabel) ? SUBREASON_LABEL_TO_ES.get(subreasonLabel) : subreasonLabel;

            if (req.damage != null) {
                for (String dano : req.damage) {
                    List<GuildCalculator__mdt> candidates = new List<GuildCalculator__mdt>();
                    for (GuildCalculator__mdt m : metadatas) {
                        if (m.Damage__c != dano) continue;

                        Boolean grandAccountMatch = (String.isBlank(m.GrandAccount__c) || m.GrandAccount__c == req.grandAccount);
                        Boolean reasonMatch = (String.isBlank(m.Reason__c) || m.Reason__c == reasonEs);
                        Boolean subreasonMatch = (String.isBlank(m.Subreason__c) || m.Subreason__c == subreasonEs);

                        if (grandAccountMatch && reasonMatch && subreasonMatch) {
                            candidates.add(m);
                        }
                    }
                    
                    Set<String> guilds = new Set<String>();
                    for (GuildCalculator__mdt c : candidates) {
                        if (!String.isBlank(c.Guild__c)) {
                            guilds.add(c.Guild__c);
                        }
                    }
                    GuildResponse res = new GuildResponse();
                    res.guild = !guilds.isEmpty() ? String.join(new List<String>(guilds), ';') : null;
                    responses.add(res);
                }
            }
        }
        return responses;
    }
}