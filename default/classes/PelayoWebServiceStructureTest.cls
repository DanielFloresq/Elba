/**
 * @description       : 
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 12-26-2025
 * @last modified by  : Daniel Flores
**/
@IsTest
public class PelayoWebServiceStructureTest {
    
    @IsTest
    static void testPelayoWebServiceStructure() {
      
        PelayoWebServiceStructure.body testBody = new PelayoWebServiceStructure.body();
        testBody.encargo = new List<PelayoWebServiceStructure.encargo>();

        
        PelayoWebServiceStructure.encargo testEncargo = new PelayoWebServiceStructure.encargo();
        testEncargo.chargeIdentifier = 'CHG123';
        testEncargo.chargeIdentifierAssignmentDate = Date.today();
        testEncargo.chargeIdentifierAssignmentTime = System.now().time(); 
        testEncargo.providerReference = 'PROV456';
        testEncargo.comment = 'Teste de encargo';
        testEncargo.urgent = true;
        testEncargo.adjusterName = 'João Ajustador';
        testEncargo.adjusterEmail = 'joao@teste.com';
        testEncargo.adjusterPhone = '123456789';
        testEncargo.adjusterMobile = '987654321';

       
        PelayoWebServiceStructure.contact testContact = new PelayoWebServiceStructure.contact();
        testContact.policyIdentifier = 'POL123';
        testContact.originChannel = 'Online';
        testContact.effectiveDate = Date.today();
        testContact.mediatedPolicy = false;
        testContact.brokerIdentifier = 'BRK001';
        testContact.vipClient = true;
        testContact.firstName = 'Maria';
        testContact.lastName1 = 'Silva';
        testContact.email = 'maria@teste.com';
        testContact.mobile = '912345678';
        testEncargo.contact = testContact;

        
        PelayoWebServiceStructure.stakeHolder testStakeHolder = new PelayoWebServiceStructure.stakeHolder();
        testStakeHolder.firstName = 'Carlos';
        testStakeHolder.firstLastName = 'Santos';
        testStakeHolder.isResponsibleParty = true;
        testStakeHolder.email = 'carlos@teste.com';
        testEncargo.stakeHolder = testStakeHolder;

     
        PelayoWebServiceStructure.siniestro testSiniestro = new PelayoWebServiceStructure.siniestro();
        testSiniestro.exponentialQuadrant = 'EQ1';
        testSiniestro.declarationDate = Date.today();
        testSiniestro.occurrenceDate = Date.today().addDays(-1);
        testSiniestro.claimDescription = 'Danos na propriedade';
        testSiniestro.vitalOrganAffected = false;
        testEncargo.siniestro = testSiniestro;

      
        testBody.encargo.add(testEncargo);

    
        System.assertEquals(1, testBody.encargo.size(), 'Deve conter 1 encargo');
        System.assertEquals('CHG123', testBody.encargo[0].chargeIdentifier, 'O identificador deve corresponder');
        System.assertEquals('Maria', testBody.encargo[0].contact.firstName, 'O firstName do contact deve corresponder');
        System.assertEquals('Carlos', testBody.encargo[0].stakeHolder.firstName, 'O firstName do stakeHolder deve corresponder');
        System.assertEquals('Danos na propriedade', testBody.encargo[0].siniestro.claimDescription, 'A descrição do siniestro deve corresponder');
    }
}