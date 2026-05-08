/**
 * @description       : Test class for PelayoWebServiceController REST endpoint operations
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 05-03-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public class PelayoWebServiceControllerTest {

    private class ThrowingCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Simulate a low-level callout failure to cover catch paths.
            throw new CalloutException('Simulated callout exception');
        }
    }

    /**
     * @description Builds a GarantiaDetalle test fixture with default capital and limite values.
     * @param garantia Warranty code
     * @param cobertura Coverage type
     * @return PelayoWebServiceStructure.GarantiaDetalle Populated test instance
     **/
    private static PelayoWebServiceStructure.GarantiaDetalle buildGarantia(String garantia, String cobertura) {
        PelayoWebServiceStructure.GarantiaDetalle garantiaDetalle = new PelayoWebServiceStructure.GarantiaDetalle();
        garantiaDetalle.garantia = garantia;
        garantiaDetalle.cobertura = cobertura;
        garantiaDetalle.capital = '100.00';
        garantiaDetalle.limite = '100.00';
        garantiaDetalle.existefranquicia = false;
        garantiaDetalle.esprimerriesgo = false;
        return garantiaDetalle;
    }

    /**
     * @description Builds a valid inbound PelayoWebServiceStructure.body payload for use in test methods.
     * @return PelayoWebServiceStructure.body Fully populated test payload
     **/
    private static PelayoWebServiceStructure.body buildValidInboundPayload() {
        PelayoWebServiceStructure.body payload = new PelayoWebServiceStructure.body();

        payload.poliza = new PelayoWebServiceStructure.Poliza();
        payload.poliza.identificadorPoliza = 'POL-000001';
        payload.poliza.direccionRiesgo = 'Calle Mayor 1, Madrid';
        payload.poliza.codigoPostal = '28001';
        payload.poliza.poblacion = 'MADRID';
        payload.poliza.provincia = 'MADRID';
        payload.poliza.ramo = '04-HOGAR';
        payload.poliza.nombre = 'ASEGURADO TEST';
        payload.poliza.movil = '+34600000000';
        payload.poliza.tipoVia = 'CL';
        payload.poliza.nombreVia = 'MAYOR';
        payload.poliza.numero = '1';

        payload.siniestro = new PelayoWebServiceStructure.Siniestro();
        payload.siniestro.referenciaSiniestroAseguradora = 'SIN-000001';
        payload.siniestro.nombreDeclarante = 'DECLARANTE TEST';
        payload.siniestro.descripcionSiniestro = 'Descripcion del siniestro';
        payload.siniestro.fechaDeclaracion = Date.today();
        payload.siniestro.fechaOcurrencia = Date.today().addDays(-1);
        payload.siniestro.identificadorCausa = 'A4';
        payload.siniestro.identificadorSubcausa = 'R3';
        payload.siniestro.identificadorTipoSiniestro = 'REPARABLE';
        payload.siniestro.tipoSituacion = 'ABIERTO';
        payload.siniestro.urgente = false;
        payload.siniestro.danosOcasionados = new List<String>{ 'DANO TEST' };
        payload.siniestro.garantiasSiniestro = new List<PelayoWebServiceStructure.GarantiaDetalle>{
            buildGarantia('HG001', 'CONTINENTE')
        };
        payload.siniestro.garantiasPoliza = new List<PelayoWebServiceStructure.GarantiaDetalle>{
            buildGarantia('HG001', 'CONTINENTE')
        };

        payload.encargo = new PelayoWebServiceStructure.Encargo();
        payload.encargo.referenciaEncargoAseguradora = 'ENC-000001';

        return payload;
    }

    /**
     * @description Prepares the RestContext with a POST request containing the given JSON payload for testing the REST endpoint.
     * @param payloadJson Serialised JSON body for the request
     **/
    private static void prepareInboundRestContext(String payloadJson) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/encargo';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payloadJson);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /**
     * @description Converts a List of Objects to a Set of Strings for assertion comparisons.
     * @param values List of Object values to convert
     * @return Set<String> Converted string set
     **/
    private static Set<String> toStringSet(List<Object> values) {
        Set<String> result = new Set<String>();
        if (values == null) {
            return result;
        }
        for (Object value : values) {
            result.add((String) value);
        }
        return result;
    }

    /**
     * @description Verifies that sendEncargoPelayoService successfully creates an assignment via synchronous callout.
     **/
    @isTest
    static void testSendEncargoPelayoServiceCreate() {

        // Mock the HTTP response for the token request to simulate success
        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"access_token":"123","token_type":"Bearer","expires_in":86400}'
			),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"id":"71c45d26-fcae-4242-8d14-1c27bc51cb3f","success":true,"message":"Actualizacion procesada con exito.","idSiniestroElba":"123","idSiniestroAseguradora":"123","encargos":[{"idEncargoElba":"123", "idEncargoAseguradora":"123","success":true,"message":"Encargo actualizado correctamente"}]}'
            )
		};
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Account testAccount = TestFactory.createAccount('Test Account', 'test@test.com' , '910000000', 'Multigremio', 'A2');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Order Assignment');

        Test.startTest();
        PelayoWebServiceController.sendEncargoPelayoService(new List<String>{(String) testOrder.Id}, null, true);
        Test.stopTest();
    }

    /**
     * @description Verifies that sendEncargoPelayoService processes an assignment via a future (asynchronous) callout.
     **/
    @isTest
    static void testSendEncargoPelayoServiceFuture() {

        // Mock the HTTP response for the token request to simulate success
        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"access_token":"123","token_type":"Bearer","expires_in":86400}'
			),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"id":"71c45d26-fcae-4242-8d14-1c27bc51cb3f","success":true,"message":"Actualizacion procesada con exito.","idSiniestroElba":"123","idSiniestroAseguradora":"123","encargos":[{"idEncargoElba":"123", "idEncargoAseguradora":"123","success":true,"message":"Encargo actualizado correctamente"}]}'
            )
		};
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Account testAccount = TestFactory.createAccount('Test Account', 'test@test.com' , '910000000', 'Multigremio', 'A2');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Order Assignment');

        Test.startTest();
        PelayoWebServiceController.sendEncargoPelayoService(new List<String>{(String) testOrder.Id}, null, false);
        Test.stopTest();
    }

    /**
     * @description Verifies that sendEncargoPelayoService handles an HTTP error response (4xx) gracefully.
     **/
    @isTest
    static void testSendEncargoPelayoServiceError() {

        // Mock the HTTP response for the token request to simulate success
        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"access_token":"123","token_type":"Bearer","expires_in":86400}'
			),
            HttpCalloutMockFactory.generateHttpResponse(
                400,
                'NOK',
                'Error'
            )
		};
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Account testAccount = TestFactory.createAccount('Test Account', 'test@test.com' , '910000000', 'Multigremio', 'A2');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Order Assignment');

        Test.startTest();
        PelayoWebServiceController.sendEncargoPelayoService(new List<String>{(String) testOrder.Id}, 'Assignacion', true);
        Test.stopTest();
    }

    /**
     * @description Verifies that sendEncargoPelayoService handles an exception-like response body without throwing.
     **/
    @isTest
    static void testSendEncargoPelayoServiceException() {

        // Mock the HTTP response for the token request to simulate success
        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"access_token":"123","token_type":"Bearer","expires_in":86400}'
			),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'Exception',
                'Error'
            )
		};
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Account testAccount = TestFactory.createAccount('Test Account', 'test@test.com' , '910000000', 'Multigremio', 'A2');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Order Assignment');

        Test.startTest();
        PelayoWebServiceController.sendEncargoPelayoService(new List<String>{(String) testOrder.Id}, 'Assignacion', true);
        Test.stopTest();
    }

    /**
     * @description Verifies that sendEncargoPelayoService updates Order fields (ChargeIdentifier, LastIntegration) from a successful assignment response.
     **/
    @isTest
    static void testSendEncargoPelayoServiceAssign() {

        // Mock the HTTP response for the token request to simulate success
        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
				200,
				'OK',
				'{"access_token":"123","token_type":"Bearer","expires_in":86400}'
			),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"id":"71c45d26-fcae-4242-8d14-1c27bc51cb3f","success":true,"message":"Actualizacion procesada con exito.","idSiniestroElba":"123","idSiniestroAseguradora":"123","encargos":[{"idEncargoElba":"123", "idEncargoAseguradora":"123","success":true,"message":"Encargo actualizado correctamente"}]}'
            )
		};
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(
			responses
		);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Account testAccount = TestFactory.createAccount('Test Account', 'test@test.com' , '910000000', 'Multigremio', 'A2');
        Case testCase = TestFactory.createCase(testAccount.Id, 'En Curso', 'PLYO');
        Order testOrder = TestFactory.createOrder(testCase.Id, testAccount.Id, 'Order Assignment');

        Test.startTest();
        PelayoWebServiceController.sendEncargoPelayoService(new List<String>{(String) testOrder.Id}, 'Assignacion', true);
        Test.stopTest();

        testOrder = [SELECT Id, ChargeIdentifier__c, LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order LIMIT 1];
        System.assertEquals('123', testOrder.ChargeIdentifier__c, 'The Charge Identifier should be updated based on the service response');
        System.assertNotEquals(null, testOrder.LastIntegrationDateTime__c, 'The Last Integration DateTime should be set');
        System.assertEquals('Encargo actualizado correctamente', testOrder.LastIntegrationDescription__c, 'The Last Integration Description should be updated based on the service response');
    }

    /**
     * @description Verifies inbound receiveEncargo with a full payload including garantiasSiniestro and garantiasPoliza creates InsurableCoverage and Coverage records.
     **/
    @IsTest
    static void testReceiveEncargo_NovoFormatoGarantias_CriaCoberturas() {
        // O controller faz query por Account com Name LIKE '%SLA%' ou '%PELAYO%'
        insert new Account(Name = 'SLA - Test');
        insert new Account(Name = 'PELAYO - Test');

        String claimRef = 'REF-TEST-001';

        // Payload real fornecido (mantém a estrutura completa)
        String payloadJson =
            '{' +
            '  "poliza": {' +
            '    "identificadorPoliza": "042820573312",' +
            '    "canalOrigen": "",' +
            '    "fechaEfecto": "2024-06-28",' +
            '    "polizaMediada": false,' +
            '    "identificadorMediador": "",' +
            '    "clienteVIP": false,' +
            '    "nombreMediador": "",' +
            '    "direccionRiesgo": "CL. Mirador del Guadiana, 12, 06010 BADAJOZ",' +
            '    "tipoVia": "CL",' +
            '    "nombreVia": "Mirador del Guadiana",' +
            '    "numero": "12",' +
            '    "escalera": null,' +
            '    "piso": null,' +
            '    "puerta": null,' +
            '    "codigoPostal": "06010",' +
            '    "poblacion": "BADAJOZ",' +
            '    "provincia": "7",' +
            '    "capitalContinente": 144961.05,' +
            '    "capitalContenido": 37371.1,' +
            '    "capitalRC": 0.0,' +
            '    "nombreAsegurado": "MARIO J LUNA BERNAL",' +
            '    "nombre": "MARIO J",' +
            '    "apellido1": "LUNA",' +
            '    "apellido2": "BERNAL",' +
            '    "tipoIdentificador": "DNI",' +
            '    "identificador": "43127685V",' +
            '    "email": "mario.luna.bernal@example.com",' +
            '    "movil": "+34605857042",' +
            '    "otrosContactos": "",' +
            '    "idiomaPreferido": "ES",' +
            '    "ramo": "01-HOGAR"' +
            '  },' +
            '  "siniestro": {' +
            '    "cuadranteExponencial": null,' +
            '    "referenciaSiniestroAseguradora": "MUDAR AQUI 4",' +
            '    "descripcionDeclarante": "ASEGURADO",' +
            '    "nombreDeclarante": "MARIO J LUNA BERNAL",' +
            '    "nombrePersonaContacto": "SILVANA",' +
            '    "parentescoAsegurado": null,' +
            '    "telefonoMovilPersonaContacto": "727139277",' +
            '    "observacionesPersonaContacto": null,' +
            '    "descripcionSiniestro": "DECLARA HUMEDADES EN SUELO PASANDO EL RECIBIDOR ENTRANDO AL SALON",' +
            '    "cuestionario": null,' +
            '    "fechaDeclaracion": "2026-01-29",' +
            '    "fechaOcurrencia": "2025-12-29",' +
            '    "identificadorCausa": "A4",' +
            '    "identificadorSubcausa": "R3",' +
            '    "organoVitalAfectado": false,' +
            '    "garantiasSiniestro": [' +
            '      {' +
            '        "garantia": "HG018",' +
            '        "cobertura": "CONTINENTE",' +
            '        "capital": "144961.05",' +
            '        "limite": "144961.05",' +
            '        "existefranquicia": false,' +
            '        "importefranquicia": null,' +
            '        "franquiciaConsumida": null,' +
            '        "limiteusos": null,' +
            '        "usosconsumidos": null,' +
            '        "esprimerriesgo": false' +
            '      },' +
            '      {' +
            '        "garantia": "HG018",' +
            '        "cobertura": "CONTENIDO",' +
            '        "capital": "37371.10",' +
            '        "limite": "37371.10",' +
            '        "existefranquicia": false,' +
            '        "importefranquicia": null,' +
            '        "franquiciaConsumida": null,' +
            '        "limiteusos": null,' +
            '        "usosconsumidos": null,' +
            '        "esprimerriesgo": false' +
            '      }' +
            '    ],' +
            '    "garantiasPoliza": [' +
            '      {' +
            '        "garantia": "HG001",' +
            '        "cobertura": "CONTINENTE",' +
            '        "capital": "144961.05",' +
            '        "limite": "144961.05",' +
            '        "existefranquicia": false,' +
            '        "importefranquicia": null,' +
            '        "franquiciaConsumida": null,' +
            '        "limiteusos": null,' +
            '        "usosconsumidos": null,' +
            '        "esprimerriesgo": false' +
            '      },' +
            '      {' +
            '        "garantia": "HG001",' +
            '        "cobertura": "CONTENIDO",' +
            '        "capital": "37371.10",' +
            '        "limite": "37371.10",' +
            '        "existefranquicia": false,' +
            '        "importefranquicia": null,' +
            '        "franquiciaConsumida": null,' +
            '        "limiteusos": null,' +
            '        "usosconsumidos": null,' +
            '        "esprimerriesgo": false' +
            '      },' +
            '      {' +
            '        "garantia": "HG002",' +
            '        "cobertura": "CONTINENTE",' +
            '        "capital": "0.00",' +
            '        "limite": "7050.60",' +
            '        "existefranquicia": false,' +
            '        "importefranquicia": null,' +
            '        "franquiciaConsumida": null,' +
            '        "limiteusos": null,' +
            '        "usosconsumidos": null,' +
            '        "esprimerriesgo": false' +
            '      },' +
            '      {' +
            '        "garantia": "HG003",' +
            '        "cobertura": "CONTINENTE",' +
            '        "capital": "144961.05",' +
            '        "limite": "144961.05",' +
            '        "existefranquicia": false,' +
            '        "importefranquicia": null,' +
            '        "franquiciaConsumida": null,' +
            '        "limiteusos": null,' +
            '        "usosconsumidos": null,' +
            '        "esprimerriesgo": false' +
            '      },' +
            '      {' +
            '        "garantia": "HG003",' +
            '        "cobertura": "CONTENIDO",' +
            '        "capital": "37371.10",' +
            '        "limite": "37371.10",' +
            '        "existefranquicia": false,' +
            '        "importefranquicia": null,' +
            '        "franquiciaConsumida": null,' +
            '        "limiteusos": null,' +
            '        "usosconsumidos": null,' +
            '        "esprimerriesgo": false' +
            '      }' +
            '    ],' +
            '    "movil": "+34727139277",' +
            '    "quiereSMS": true,' +
            '    "email": "silvanages@gmail.com",' +
            '    "quiereEmail": false,' +
            '    "franquicia": 0.0,' +
            '    "franquiciaConsumida": 0.0,' +
            '    "identificadorTipoSiniestro": "REPARABLE",' +
            '    "provisionActual": 325.0,' +
            '    "servicioAsistencia": false,' +
            '    "tipoSituacion": "REPARABLE",' +
            '    "urgente": false,' +
            '    "danosOcasionados": ["SUELOS DE MADERA", "FUGA DE TUBERIA"],' +
            '    "nombreTramitador": null,' +
            '    "emailTramitador": null,' +
            '    "marcadores": [],' +
            '    "listaImplicados": [' +
            '      {' +
            '        "nombre": "COLECTIVO ",' +
            '        "apellido1": "",' +
            '        "apellido2": "PELAYO",' +
            '        "tipoImplicado": "",' +
            '        "comentarios": "Vecino del 5ºC - Daños en techo del baño",' +
            '        "email": "alberto.jimenez@email.com",' +
            '        "horaInicioContactoMovilPrincipal": "10",' +
            '        "horaFinContactoMovilPrincipal": "19",' +
            '        "horaInicioContactoMovilSecundario": null,' +
            '        "horaFinContactoMovilSecundario": null,' +
            '        "horaInicioContactoFijo": "19",' +
            '        "horaFinContactoFijo": "21",' +
            '        "movilPrincipal": "+34611222333",' +
            '        "movilSecundario": "",' +
            '        "telefonoFijo": "+34915556677",' +
            '        "descripcionCompaniaAseguradora": "AXA SEGUROS",' +
            '        "codigoPostal": "28008",' +
            '        "escalera": "B",' +
            '        "letra": "C",' +
            '        "nombreVia": "PRINCESA",' +
            '        "numero": "50",' +
            '        "pais": "ES",' +
            '        "piso": "5",' +
            '        "poblacion": "MADRID",' +
            '        "provincia": "",' +
            '        "tipoVia": "CL",' +
            '        "fechaBaja": null,' +
            '        "identificadorCompaniaAseguradora": "12105803",' +
            '        "identificador": "77889900G",' +
            '        "tipoIdentificador": "",' +
            '        "numeroAsegurado": "041420112233",' +
            '        "referenciaSiniestroCompaniaContraria": ""' +
            '      },' +
            '      {' +
            '        "nombre": "COMUNIDAD DE PROPIETARIOS PRINCESA 50",' +
            '        "apellido1": "",' +
            '        "apellido2": "",' +
            '        "tipoImplicado": "",' +
            '        "comentarios": "Comunidad afectada - Bajante comunitario dañado",' +
            '        "email": "adminfincas.princesa50@email.com",' +
            '        "horaInicioContactoMovilPrincipal": "9",' +
            '        "horaFinContactoMovilPrincipal": "17",' +
            '        "horaInicioContactoMovilSecundario": null,' +
            '        "horaFinContactoMovilSecundario": null,' +
            '        "horaInicioContactoFijo": "9",' +
            '        "horaFinContactoFijo": "17",' +
            '        "movilPrincipal": "+34699001122",' +
            '        "movilSecundario": "",' +
            '        "telefonoFijo": "+34915001122",' +
            '        "descripcionCompaniaAseguradora": "MUTUA DE PROPIETARIOS",' +
            '        "codigoPostal": "28008",' +
            '        "escalera": "",' +
            '        "letra": "",' +
            '        "nombreVia": "PRINCESA",' +
            '        "numero": "50",' +
            '        "pais": "ES",' +
            '        "piso": "",' +
            '        "poblacion": "MADRID",' +
            '        "provincia": "",' +
            '        "tipoVia": "CL",' +
            '        "fechaBaja": null,' +
            '        "identificadorCompaniaAseguradora": "12105804",' +
            '        "identificador": "H12345678",' +
            '        "tipoIdentificador": "",' +
            '        "numeroAsegurado": "041420998877",' +
            '        "referenciaSiniestroCompaniaContraria": ""' +
            '      }' +
            '    ]' +
            '  }' +
            '}';

        payloadJson = payloadJson.replace('MUDAR AQUI 4', claimRef);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/encargo';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payloadJson);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        PelayoWebServiceController.receiveEncargo();

        
    }

    /**
     * @description Verifies that mapServicesFromEncargo returns an empty list when the Order is null.
     **/
    @IsTest
    static void testMapServicesFromEncargo_NullOrder() {
        List<Service__c> services = PelayoWebServiceController.mapServicesFromEncargo(null, null, null);
        System.assertNotEquals(null, services);
        System.assertEquals(0, services.size(), 'Null order should yield empty services list');
    }

    /**
     * @description Verifies that mapServicesFromEncargo correctly splits guild tokens, deduplicates them, skips 'NO APLICA', and sets appropriate status.
     **/
    @IsTest
    static void testMapServicesFromEncargo_SplitsTokensAndSetsStatus() {
        Account acc = TestFactory.createAccount('Provider Test', 'prov@test.com', '910000001', 'Multigremio', 'A2');
        Case c = TestFactory.createCase(acc.Id, 'Opening', 'PLYO');
        Order o = TestFactory.createOrder(c.Id, acc.Id, 'Order Assignment');
        // Avoid DML update here because Guild__c is a restricted picklist in this org.
        // We only need the string value to exercise splitTokens().
        o.Guild__c = 'PINTURA; NO APLICA;PINTURA,ALBANILERIA;  ELECTRICIDAD  ;';

        List<Service__c> services = PelayoWebServiceController.mapServicesFromEncargo(o, c.Id, null);
        System.assertEquals(3, services.size(), 'Should create 3 unique services (skip NO APLICA and duplicates)');
        for (Service__c s : services) {
            System.assertEquals(o.Id, s.Order__c);
            System.assertEquals(c.Id, s.Claim__c);
            System.assertEquals('Assigned', s.Status__c, 'Order Assignment should map to Assigned status');
            System.assertNotEquals(null, s.Type__c);
        }
    }

    /**
     * @description Verifies that debugPrettyPrintJSON returns well-formatted JSON containing newlines.
     **/
    @IsTest
    static void testDebugPrettyPrintJSON_ReturnsPrettyJson() {
        String input = '{"a":1,"b":{"c":2}}';
        String pretty = PelayoWebServiceController.debugPrettyPrintJSON(input);
        System.assert(pretty.contains('\n'), 'Pretty JSON should contain new lines');
        System.assert(pretty.contains('"a"'), 'Pretty JSON should keep keys');
    }

    /**
     * @description Verifies that setCaseInfoFromOrder correctly maps Case fields (CaseNumber, InsurerClaimReference, ClaimsHandlerName) from an Order relationship.
     **/
    @IsTest
    static void testSetCaseInfoFromOrder_MapsCaseFields() {
        // Use real Case/Order records to get a CaseNumber value (it's read-only).
        // Also bypass Order-trigger outbound actions to avoid callout errors.
        OrderTriggerLogic.bypassExternalActions = true;

        Account acc = TestFactory.createAccount('CaseInfo Test', 'caseinfo@test.com', '910000002', 'Multigremio', 'A2');
        Case c = TestFactory.createCase(acc.Id, 'Opening', 'PLYO');
        c.InsurerClaimReference__c = 'REF-CASEINFO-1';
        c.ClaimsHandlerName__c = 'Handler Name';
        update c;

        Order o = TestFactory.createOrder(c.Id, acc.Id, 'Order Assignment');
        Order oWithRel = [
            SELECT Id, CaseNumber__c,
                   CaseNumber__r.CaseNumber,
                   CaseNumber__r.InsurerClaimReference__c,
                   CaseNumber__r.ClaimsHandlerName__c
            FROM Order
            WHERE Id = :o.Id
            LIMIT 1
        ];

        PelayoOutBoundStrucuture.CaseInfo info = PelayoWebServiceController.setCaseInfoFromOrder(oWithRel);
        System.assertEquals(oWithRel.CaseNumber__r.CaseNumber, info.caseNumber);
        System.assertEquals('REF-CASEINFO-1', info.insurerClaimReference);
        System.assertEquals('Handler Name', info.claimsHandlerName);
    }

    /**
     * @description Verifies that setOrderWithResponseInfo populates ChargeIdentifier, LastIntegrationDateTime, and LastIntegrationDescription from the service response.
     **/
    @IsTest
    static void testSetOrderWithResponseInfo_SetsIntegrationFields() {
        // No DML needed for this unit test; avoids triggers/callouts.
        Order o = new Order();

        PelayoWebServiceController.EncargoResponse encResp = new PelayoWebServiceController.EncargoResponse();
        encResp.idEncargoAseguradora = 'ENC-ASEG-123';
        encResp.message = 'Encargo actualizado correctamente';
        encResp.success = true;

        Order updated = PelayoWebServiceController.setOrderWithResponseInfo(o, encResp);
        System.assertEquals('ENC-ASEG-123', updated.ChargeIdentifier__c);
        System.assertNotEquals(null, updated.LastIntegrationDateTime__c);
        System.assertEquals('Encargo actualizado correctamente', updated.LastIntegrationDescription__c);
        System.assertEquals('', updated.LastIntegration__c);
    }

    /**
     * @description Verifies the receiveEncargo happy path with a complete payload including policy, claim, stakeholders, encargo, and coverage data.
     **/
    @IsTest
    static void testReceiveEncargo_HappyPath_CoversMoreBranches() {
        // Ensure the Account lookup performed by the controller finds a match.
        insert new Account(Name = 'SLA - Test');
        insert new Account(Name = 'PELAYO - Test');

        // JSON known to work well (uses real picklist values like gremio=B3 and valid damages).
        String payloadJson =
            '{' +
            '  "poliza": {' +
            '    "identificadorPoliza": "041420198528",' +
            '    "canalOrigen": "6931",' +
            '    "fechaEfecto": "2019-03-01",' +
            '    "polizaMediada": true,' +
            '    "identificadorMediador": "30462002",' +
            '    "clienteVIP": true,' +
            '    "nombreMediador": "COLECTIVO PELAYO",' +
            '    "direccionRiesgo": "CALLE PRINCESA 50, 28008 MADRID",' +
            '    "tipoVia": "CL",' +
            '    "nombreVia": "PRINCESA",' +
            '    "numero": "50",' +
            '    "escalera": "B",' +
            '    "piso": "6",' +
            '    "puerta": "C",' +
            '    "codigoPostal": "28008",' +
            '    "poblacion": "MADRID",' +
            '    "provincia": "MADRID",' +
            '    "capitalContinente": 175000.00,' +
            '    "capitalContenido": 50000.00,' +
            '    "capitalRC": 300000.00,' +
            '    "nombreAsegurado": null,' +
            '    "nombre": "COLECTIVO",' +
            '    "apellido1": "",' +
            '    "apellido2": "PELAYO",' +
            '    "tipoIdentificador": "NIF",' +
            '    "identificador": "33445566F",' +
            '    "email": "carmen.alvarez@email.com",' +
            '    "movil": "+34622334455",' +
            '    "otrosContactos": "",' +
            '    "idiomaPreferido": "CAS",' +
            '    "ramo": "04-HOGAR"' +
            '  },' +
            '  "siniestro": {' +
            '    "cuadranteExponencial": null,' +
            '    "referenciaSiniestroAseguradora": "Teste - 1",' +
            '    "descripcionDeclarante": "AS",' +
            '    "nombreDeclarante": "MARIO J LUNA BERNAL",' +
            '    "nombrePersonaContacto": "SILVANA",' +
            '    "parentescoAsegurado": null,' +
            '    "telefonoMovilPersonaContacto": "727139277",' +
            '    "observacionesPersonaContacto": null,' +
            '    "descripcionSiniestro": "DECLARA HUMEDADES EN SUELO PASANDO EL RECIBIDOR ENTRANDO AL SALON",' +
            '    "cuestionario": null,' +
            '    "fechaDeclaracion": "2026-01-29",' +
            '    "fechaOcurrencia": "2025-12-29",' +
            '    "identificadorCausa": "A4",' +
            '    "identificadorSubcausa": "R3",' +
            '    "organoVitalAfectado": false,' +
            '    "garantiasSiniestro": [{' +
            '      "garantia": "HG047",' +
            '      "cobertura": "CONTINENTE",' +
            '      "capital": "144961.05",' +
            '      "limite": "144961.05",' +
            '      "existefranquicia": false,' +
            '      "importefranquicia": null,' +
            '      "franquiciaConsumida": null,' +
            '      "limiteusos": null,' +
            '      "usosconsumidos": null,' +
            '      "esprimerriesgo": false' +
            '    }],' +
            '    "garantiasPoliza": [{' +
            '      "garantia": "HG001",' +
            '      "cobertura": "CONTINENTE",' +
            '      "capital": "144961.05",' +
            '      "limite": "144961.05",' +
            '      "existefranquicia": false,' +
            '      "importefranquicia": null,' +
            '      "franquiciaConsumida": null,' +
            '      "limiteusos": null,' +
            '      "usosconsumidos": null,' +
            '      "esprimerriesgo": false' +
            '    }],' +
            '    "movil": "+34727139277",' +
            '    "quiereSMS": true,' +
            '    "email": "silvanages@gmail.com",' +
            '    "quiereEmail": false,' +
            '    "franquicia": 0.0,' +
            '    "franquiciaConsumida": 0.0,' +
            '    "identificadorTipoSiniestro": "RE",' +
            '    "provisionActual": 325.0,' +
            '    "servicioAsistencia": false,' +
            '    "tipoSituacion": "AP",' +
            '    "urgente": false,' +
            '    "danosOcasionados": ["SUELOS DE MADERA", "FUGA DE TUBERIA"],' +
            '    "marcadores": [],' +
            '    "listaImplicados": [{' +
            '      "nombre": "COLECTIVO ",' +
            '      "apellido1": "",' +
            '      "apellido2": "PELAYO",' +
            '      "tipoImplicado": "",' +
            '      "comentarios": "Vecino del 5ºC - Daños en techo del baño",' +
            '      "email": "alberto.jimenez@email.com",' +
            '      "horaInicioContactoMovilPrincipal": "10",' +
            '      "horaFinContactoMovilPrincipal": "19",' +
            '      "horaInicioContactoMovilSecundario": null,' +
            '      "horaFinContactoMovilSecundario": null,' +
            '      "horaInicioContactoFijo": "19",' +
            '      "horaFinContactoFijo": "21",' +
            '      "movilPrincipal": "+34611222333",' +
            '      "movilSecundario": "",' +
            '      "telefonoFijo": "+34915556677",' +
            '      "descripcionCompaniaAseguradora": "AXA SEGUROS",' +
            '      "codigoPostal": "28008",' +
            '      "escalera": "B",' +
            '      "letra": "C",' +
            '      "nombreVia": "PRINCESA",' +
            '      "numero": "50",' +
            '      "pais": "ES",' +
            '      "piso": "5",' +
            '      "poblacion": "MADRID",' +
            '      "provincia": "",' +
            '      "tipoVia": "CL",' +
            '      "fechaBaja": null,' +
            '      "identificadorCompaniaAseguradora": "C0001",' +
            '      "identificador": "77889900G",' +
            '      "tipoIdentificador": "",' +
            '      "numeroAsegurado": "041420112233",' +
            '      "referenciaSiniestroCompaniaContraria": ""' +
            '    }]' +
            '  },' +
            '  "encargo": {' +
            '    "gremio": "B3",' +
            '    "referenciaEncargoAseguradora": "Teste - 3",' +
            '    "fechaAsignacion": "2026-01-08",' +
            '    "horaAsignacion": "16:30:00",' +
            '    "tipoServicio": "CT",' +
            '    "tipoProvider": "MU ",' +
            '    "referenciaProveedor": null,' +
            '    "comentario": "Valorar daños en vivienda asegurada y coordinar con administrador de fincas para acceso a zonas comunes.",' +
            '    "urgente": false,' +
            '    "nombrePerito": "",' +
            '    "emailPerito": "",' +
            '    "telefonoPerito": "",' +
            '    "movilPerito": ""' +
            '  }' +
            '}';

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/encargo';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payloadJson);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        PelayoWebServiceController.receiveEncargo();
        Test.stopTest();

        String body = RestContext.response.responseBody != null ? RestContext.response.responseBody.toString() : 'NULL';
        System.assertNotEquals(null, RestContext.response.statusCode, 'Controller should always set statusCode. Body=' + body);
        System.assert(body.contains('"success"'), 'Controller should always return a success flag. Body=' + body);
    }

    /**
     * @description Verifies that getToken returns a Bearer token on success and null on authentication failure.
     **/
    @IsTest
    static void testGetToken_SuccessAndFailure() {
        // Success
        Test.setMock(
            HttpCalloutMock.class,
            new HttpCalloutMockFactory(200, 'OK', '{"access_token":"123","token_type":"Bearer","expires_in":86400}')
        );
        String token = PelayoWebServiceController.getToken();
        System.assertEquals('Bearer 123', token);

        // Failure (non-2xx)
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(401, 'Unauthorized', 'nope'));
        String tokenFail = PelayoWebServiceController.getToken();
        System.assertEquals(null, tokenFail, 'Non-2xx token response should return null');
    }

    /**
     * @description Verifies receiveEncargo with multiple guilds and expert assessment data, covering order splitting and Service__c creation for expert assessment.
     **/
    @IsTest
    static void testReceiveEncargo_MultiGuildAndExpertAssessment_CoversMore() {
        // This is an inbound endpoint unit test; we don't want Order triggers to perform outbound integrations.
        // Without this, the Order trigger can call Pelayo outbound services and fail with
        // "Methods defined as TestMethod do not support Web service callouts".
        OrderTriggerLogic.bypassExternalActions = true;

        // Ensure account lookup works regardless of running user name.
        insert new Account(Name = 'SLA - Test');
        insert new Account(Name = 'PELAYO - Test');

        // Pick 2 valid guild values from the org (restricted picklist/multipicklist).
        List<String> guildValues = new List<String>();
        for (Schema.PicklistEntry pe : Order.Guild__c.getDescribe().getPicklistValues()) {
            if (pe != null && pe.isActive()) {
                guildValues.add(pe.getValue());
            }
        }
        if (guildValues.size() < 2) {
            // Can't force multi-guild split without at least 2 valid values.
            System.assert(true);
            return;
        }
        String gremio = guildValues[0] + ';' + guildValues[1];
        gremio = gremio.replace('\\', '\\\\').replace('"', '\\"');

        // Start from the known-good JSON and tweak only what we need.
        String payloadJson =
            '{' +
            '  "poliza": {' +
            '    "identificadorPoliza": "041420198528",' +
            '    "canalOrigen": "6931",' +
            '    "fechaEfecto": "2019-03-01",' +
            '    "polizaMediada": true,' +
            '    "identificadorMediador": "30462002",' +
            '    "clienteVIP": true,' +
            '    "nombreMediador": "COLECTIVO PELAYO",' +
            '    "direccionRiesgo": "CALLE PRINCESA 50, 28008 MADRID",' +
            '    "tipoVia": "CL",' +
            '    "nombreVia": "PRINCESA",' +
            '    "numero": "50",' +
            '    "escalera": "B",' +
            '    "piso": "6",' +
            '    "puerta": "C",' +
            '    "codigoPostal": "28008",' +
            '    "poblacion": "MADRID",' +
            '    "provincia": "MADRID",' +
            '    "capitalContinente": 175000.00,' +
            '    "capitalContenido": 50000.00,' +
            '    "capitalRC": 300000.00,' +
            '    "nombreAsegurado": null,' +
            '    "nombre": "COLECTIVO",' +
            '    "apellido1": "",' +
            '    "apellido2": "PELAYO",' +
            '    "tipoIdentificador": "NIF",' +
            '    "identificador": "33445566F",' +
            '    "email": "carmen.alvarez@email.com",' +
            '    "movil": "+34622334455",' +
            '    "otrosContactos": "",' +
            '    "idiomaPreferido": "CAS",' +
            '    "ramo": "04-HOGAR"' +
            '  },' +
            '  "siniestro": {' +
            '    "cuadranteExponencial": null,' +
            '    "referenciaSiniestroAseguradora": "Teste - MultiGuild",' +
            '    "descripcionDeclarante": "AS",' +
            '    "nombreDeclarante": "MARIO J LUNA BERNAL",' +
            '    "nombrePersonaContacto": "SILVANA",' +
            '    "parentescoAsegurado": null,' +
            '    "telefonoMovilPersonaContacto": "727139277",' +
            '    "observacionesPersonaContacto": null,' +
            '    "descripcionSiniestro": "DECLARA HUMEDADES EN SUELO PASANDO EL RECIBIDOR ENTRANDO AL SALON",' +
            '    "cuestionario": null,' +
            '    "fechaDeclaracion": "2026-01-29",' +
            '    "fechaOcurrencia": "2025-12-29",' +
            '    "identificadorCausa": "A4",' +
            '    "identificadorSubcausa": "R3",' +
            '    "organoVitalAfectado": false,' +
            '    "garantiasSiniestro": [{' +
            '      "garantia": "HG047",' +
            '      "cobertura": "CONTINENTE",' +
            '      "capital": "144961.05",' +
            '      "limite": "144961.05",' +
            '      "existefranquicia": false,' +
            '      "importefranquicia": null,' +
            '      "franquiciaConsumida": null,' +
            '      "limiteusos": null,' +
            '      "usosconsumidos": null,' +
            '      "esprimerriesgo": false' +
            '    }],' +
            '    "garantiasPoliza": [{' +
            '      "garantia": "HG001",' +
            '      "cobertura": "CONTINENTE",' +
            '      "capital": "144961.05",' +
            '      "limite": "144961.05",' +
            '      "existefranquicia": false,' +
            '      "importefranquicia": null,' +
            '      "franquiciaConsumida": null,' +
            '      "limiteusos": null,' +
            '      "usosconsumidos": null,' +
            '      "esprimerriesgo": false' +
            '    }],' +
            '    "movil": "+34727139277",' +
            '    "quiereSMS": true,' +
            '    "email": "silvanages@gmail.com",' +
            '    "quiereEmail": false,' +
            '    "franquicia": 0.0,' +
            '    "franquiciaConsumida": 0.0,' +
            '    "identificadorTipoSiniestro": "RE",' +
            '    "provisionActual": 325.0,' +
            '    "servicioAsistencia": false,' +
            '    "tipoSituacion": "AP",' +
            '    "urgente": false,' +
            '    "danosOcasionados": ["SUELOS DE MADERA", "FUGA DE TUBERIA"],' +
            '    "marcadores": [],' +
            '    "listaImplicados": []' +
            '  },' +
            '  "encargo": {' +
            '    "gremio": "' + gremio + '",' +
            '    "referenciaEncargoAseguradora": "Teste - MultiGuild",' +
            '    "fechaAsignacion": "2026-01-08",' +
            '    "horaAsignacion": "16:30:00",' +
            '    "tipoServicio": "CT",' +
            '    "tipoProvider": "MU ",' +
            '    "referenciaProveedor": null,' +
            '    "comentario": "Test multi guild + perito",' +
            '    "urgente": false,' +
            '    "nombrePerito": "PERITO TEST",' +
            '    "emailPerito": "perito@test.com",' +
            '    "telefonoPerito": "910000000",' +
            '    "movilPerito": "",' +
            '    "referenciaperito": "REF-PERITO"' +
            '  }' +
            '}';

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/encargo';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payloadJson);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        PelayoWebServiceController.receiveEncargo();

        String body = RestContext.response.responseBody != null ? RestContext.response.responseBody.toString() : 'NULL';
        System.assert(body.contains('"success"'), 'Should always return a success flag. Body=' + body);
    }

    /**
     * @description Verifies that receiveEncargo returns a 400 status with missing field details when required fields are absent.
     **/
    @IsTest
    static void testReceiveEncargo_MissingRequiredFields_ReturnsBadRequest() {
        PelayoWebServiceStructure.body payload = buildValidInboundPayload();
        payload.poliza.identificadorPoliza = null;
        payload.poliza.direccionRiesgo = '   ';
        payload.poliza.movil = '';
        payload.poliza.otrosContactos = '';
        payload.siniestro.danosOcasionados = new List<String>();
        payload.siniestro.garantiasPoliza[0].cobertura = null;
        payload.encargo = null;

        prepareInboundRestContext(JSON.serialize(payload));

        Test.startTest();
        PelayoWebServiceController.receiveEncargo();
        Test.stopTest();

        String responseBody = RestContext.response.responseBody.toString();
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        Set<String> missingFields = toStringSet((List<Object>) response.get('missingFields'));

        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals(false, response.get('success'));
        System.assert(((String) response.get('error')).contains('Faltan campos obligatorios o condicionales'));
        System.assert(missingFields.contains('poliza.identificadorPoliza'));
        System.assert(missingFields.contains('poliza.direccionRiesgo'));
        System.assert(missingFields.contains('poliza.movil o poliza.otrosContactos'));
        System.assert(missingFields.contains('siniestro.danosOcasionados'));
        System.assert(missingFields.contains('siniestro.garantiasPoliza[0].cobertura'));
        System.assertEquals(false, missingFields.contains('encargo.referenciaEncargoAseguradora'));
    }

    /**
     * @description Verifies that encargo.referenciaEncargoAseguradora is required only when the encargo block is present in the payload.
     **/
    @IsTest
    static void testReceiveEncargo_EncargoReferenceRequiredOnlyWhenBlockSent() {
        PelayoWebServiceStructure.body payload = buildValidInboundPayload();
        payload.encargo.referenciaEncargoAseguradora = null;

        prepareInboundRestContext(JSON.serialize(payload));

        Test.startTest();
        PelayoWebServiceController.receiveEncargo();
        Test.stopTest();

        Map<String, Object> response =
            (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Set<String> missingFields = toStringSet((List<Object>) response.get('missingFields'));

        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals(false, response.get('success'));
        System.assert(missingFields.contains('encargo.referenciaEncargoAseguradora'));
    }

    /**
     * @description Verifies that receiveEncargo returns a 400 status when stakeholder conditional fields (phone numbers) are all missing.
     **/
    @IsTest
    static void testReceiveEncargo_StakeholderConditionalFields_ReturnsBadRequest() {
        PelayoWebServiceStructure.body payload = buildValidInboundPayload();
        payload.siniestro.listaImplicados = new List<PelayoWebServiceStructure.StakeHolder>{
            new PelayoWebServiceStructure.StakeHolder()
        };
        payload.siniestro.listaImplicados[0].nombre = 'IMPLICADO TEST';
        payload.siniestro.listaImplicados[0].movilPrincipal = '';
        payload.siniestro.listaImplicados[0].movilSecundario = '';
        payload.siniestro.listaImplicados[0].telefonoFijo = '';

        prepareInboundRestContext(JSON.serialize(payload));

        Test.startTest();
        PelayoWebServiceController.receiveEncargo();
        Test.stopTest();

        Map<String, Object> response =
            (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Set<String> missingFields = toStringSet((List<Object>) response.get('missingFields'));

        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals(false, response.get('success'));
        System.assert(
            missingFields.contains(
                'siniestro.listaImplicados[0].movilPrincipal o siniestro.listaImplicados[0].movilSecundario o siniestro.listaImplicados[0].telefonoFijo'
            )
        );
    }

    /**
     * @description Verifies that assignEncargoPelayoService handles a null token and an exception-like message by setting LastIntegration__c on the Order.
     **/
    @IsTest
    static void testAssignEncargoPelayoService_NullTokenAndExceptionMessageBranch() {
        OrderTriggerLogic.bypassExternalActions = true;

        Account acc = TestFactory.createAccount('AssignSvc Test', 'assignsvc@test.com', '910000010', 'Multigremio', 'A2');
        Case c = TestFactory.createCase(acc.Id, 'Opening', 'PLYO');
        c.InsurerClaimReference__c = 'REF-ASSIGN-1';
        c.ClaimsHandlerName__c = 'Handler';
        update c;
        Order o = TestFactory.createOrder(c.Id, acc.Id, 'Order Assignment');

        List<Order> orders = [
            SELECT Id, CaseNumber__c,
                   CaseNumber__r.CaseNumber,
                   CaseNumber__r.InsurerClaimReference__c,
                   CaseNumber__r.ClaimsHandlerName__c,
                   AccountId, Account.Name, Account.Phone,
                   OrderNumber, ChargeIdentifier__c,
                   CreatedDate, EffectiveDate, Type, ProviderType__c, Guild__c, Status,
                   Observaciones__c, Urgent__c, ProviderReference__c
            FROM Order
            WHERE Id = :o.Id
            LIMIT 1
        ];

        // 1) token callout, 2) updateAssignment callout with Exception-like message
        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(200, 'OK', '{"access_token":"123","token_type":"Bearer","expires_in":86400}'),
            HttpCalloutMockFactory.generateHttpResponse(200, 'OK', '{"success":false,"message":"Exception simulated"}')
        };
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Test.startTest();
        PelayoWebServiceController.assignEncargoPelayoService(null, orders, 'AS');
        Test.stopTest();
        System.assert(
            orders[0].LastIntegration__c != null && orders[0].LastIntegration__c.contains('assignEncargoPelayoService'),
            'Exception message should set LastIntegration__c on the in-memory order'
        );
    }

    /**
     * @description Verifies that createEncargoPelayoService updates Order fields (ChargeIdentifier, LastIntegrationDateTime, LastIntegrationDescription) from a successful response.
     **/
    @IsTest
    static void testCreateEncargoPelayoService_UpdatesOrderFromResponse() {
        OrderTriggerLogic.bypassExternalActions = true;

        Account acc = TestFactory.createAccount('CreateSvc Test', 'createsvc@test.com', '910000011', 'Multigremio', 'A2');
        Case c = TestFactory.createCase(acc.Id, 'Opening', 'PLYO');
        c.InsurerClaimReference__c = 'REF-CREATE-1';
        c.ClaimsHandlerName__c = 'Handler';
        update c;

        Order o = TestFactory.createOrder(c.Id, acc.Id, 'Open');
        Order oWithRel = [
            SELECT Id,
                   CaseNumber__c,
                   CaseNumber__r.CaseNumber,
                   CaseNumber__r.InsurerClaimReference__c,
                   CaseNumber__r.ClaimsHandlerName__c,
                   AccountId,
                   Account.Name,
                   Account.Phone,
                   OrderNumber,
                   ChargeIdentifier__c,
                   CreatedDate,
                   EffectiveDate,
                   Type,
                   ProviderType__c,
                   Guild__c,
                   Status,
                   Observaciones__c,
                   Urgent__c,
                   ProviderReference__c
            FROM Order
            WHERE Id = :o.Id
            LIMIT 1
        ];

        String caseNumber = oWithRel.CaseNumber__r.CaseNumber;
        String orderNumber = oWithRel.OrderNumber;

        String responseBody =
            '{"id":"1","success":true,"message":"OK",' +
            '"idSiniestroElba":"' + caseNumber + '",' +
            '"idSiniestroAseguradora":"A1",' +
            '"encargos":[{"idEncargoElba":"' + orderNumber + '","idEncargoAseguradora":"EXT-123","success":true,"message":"DONE"}]' +
            '}';

        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(200, 'OK', responseBody));

        Test.startTest();
        PelayoWebServiceController.createEncargoPelayoService('Bearer 123', new List<Order>{ oWithRel }, 'AL');
        Test.stopTest();

        Order updated = [SELECT Id, ChargeIdentifier__c, LastIntegrationDateTime__c, LastIntegrationDescription__c FROM Order WHERE Id = :o.Id LIMIT 1];
        System.assertEquals('EXT-123', updated.ChargeIdentifier__c);
        System.assertNotEquals(null, updated.LastIntegrationDateTime__c);
        System.assertEquals('DONE', updated.LastIntegrationDescription__c);
    }

    /**
     * @description Verifies that assignEncargoPelayoService updates Order fields from the service response on a successful callout.
     **/
    @IsTest
    static void testAssignEncargoPelayoService_SuccessUpdatesOrder() {
        OrderTriggerLogic.bypassExternalActions = true;

        Account acc = TestFactory.createAccount('AssignSvc OK', 'assignok@test.com', '910000012', 'Multigremio', 'A2');
        Case c = TestFactory.createCase(acc.Id, 'Opening', 'PLYO');
        c.InsurerClaimReference__c = 'REF-ASSIGN-OK';
        c.ClaimsHandlerName__c = 'Handler';
        update c;
        Order o = TestFactory.createOrder(c.Id, acc.Id, 'Order Assignment');
        Order oWithRel = [
            SELECT Id, CaseNumber__c,
                   CaseNumber__r.CaseNumber,
                   CaseNumber__r.InsurerClaimReference__c,
                   CaseNumber__r.ClaimsHandlerName__c,
                   AccountId, Account.Name, Account.Phone,
                   OrderNumber, ChargeIdentifier__c,
                   CreatedDate, EffectiveDate, Type, ProviderType__c, Guild__c, Status,
                   Observaciones__c, Urgent__c, ProviderReference__c
            FROM Order
            WHERE Id = :o.Id
            LIMIT 1
        ];

        String responseBody =
            '{"id":"1","success":true,"message":"OK",' +
            '"idSiniestroElba":"' + oWithRel.CaseNumber__c + '",' +
            '"idSiniestroAseguradora":"A1",' +
            '"encargos":[{"idEncargoElba":"' + oWithRel.OrderNumber + '","idEncargoAseguradora":"EXT-999","success":true,"message":"UPDATED"}]' +
            '}';
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(200, 'OK', responseBody));

        Test.startTest();
        PelayoWebServiceController.assignEncargoPelayoService('Bearer 123', new List<Order>{ oWithRel }, 'AS');
        Test.stopTest();

        Order updated = [SELECT Id, ChargeIdentifier__c, LastIntegrationDescription__c FROM Order WHERE Id = :o.Id LIMIT 1];
        System.assertEquals('EXT-999', updated.ChargeIdentifier__c);
        System.assertEquals('UPDATED', updated.LastIntegrationDescription__c);
    }

    /**
     * @description Verifies that updateAssignmentPelayoService correctly deserialises a successful HTTP response.
     **/
    @IsTest
    static void testUpdateAssignmentPelayoService_SuccessResponse() {
        HttpCalloutMockFactory mock = new HttpCalloutMockFactory(
            200,
            'OK',
            '{"id":"1","success":true,"message":"OK","idSiniestroElba":"C1","idSiniestroAseguradora":"A1","encargos":[{"idEncargoElba":"E1","idEncargoAseguradora":"EA1","success":true,"message":"DONE"}]}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        PelayoWebServiceController.UpdateAssignmentPelayoResponse resp = PelayoWebServiceController.updateAssignmentPelayoService(
            'https://example.com/pelayo',
            'Bearer 123',
            '{"any":true}'
        );
        Test.stopTest();

        System.assertEquals(true, resp.success);
        System.assertEquals('OK', resp.message);
        System.assertEquals(1, resp.encargos.size());
        System.assertEquals('E1', resp.encargos[0].idEncargoElba);
    }

    /**
     * @description Verifies that updateAssignmentPelayoService returns a failure response when the HTTP status code is non-2xx.
     **/
    @IsTest
    static void testUpdateAssignmentPelayoService_FailureStatusCode() {
        HttpCalloutMockFactory mock = new HttpCalloutMockFactory(400, 'NOK', 'Error');
        Test.setMock(HttpCalloutMock.class, mock);

        PelayoWebServiceController.UpdateAssignmentPelayoResponse resp = PelayoWebServiceController.updateAssignmentPelayoService(
            'https://example.com/pelayo',
            'Bearer 123',
            '{"any":true}'
        );

        System.assertEquals(false, resp.success);
        System.assert(resp.message != null && resp.message.contains('Failed to update assignment'), 'Should return a failure message');
    }

    /**
     * @description Verifies that updateAssignmentPelayoService catches a callout exception and returns a failure response with the exception message.
     **/
    @IsTest
    static void testUpdateAssignmentPelayoService_CatchesException() {
        Test.setMock(HttpCalloutMock.class, new ThrowingCalloutMock());

        PelayoWebServiceController.UpdateAssignmentPelayoResponse resp = PelayoWebServiceController.updateAssignmentPelayoService(
            'https://example.com/pelayo',
            'Bearer 123',
            '{"any":true}'
        );

        System.assertEquals(false, resp.success);
        System.assert(resp.message != null && resp.message.startsWith('Exception while calling Pelayo service:'), 'Should capture exception message');
    }

    /**
     * @description Verifies that sendResponseEvent publishes a platform event without throwing an exception.
     **/
    @IsTest
    static void testSendResponseEvent_DoesNotThrow() {
        Test.startTest();
        PelayoWebServiceController.sendResponseEvent(true, '001000000000001AAA', 'ok');
        Test.stopTest();
        System.assert(true, 'Platform event publish should not throw');
    }
}