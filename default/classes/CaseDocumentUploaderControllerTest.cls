/**
 * @description       : 
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 01-09-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public class CaseDocumentUploaderControllerTest {

    /* ---------- AUXILIAR ---------- */
    private static Case createCase() {
        Case c = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Phone'
        );
        insert c;
        return c;
    }

    private static CaseDocumentUploaderController.FileWrapper createFile(String name) {
        CaseDocumentUploaderController.FileWrapper fw =
            new CaseDocumentUploaderController.FileWrapper();
        fw.fileName = name;
        fw.base64Data = EncodingUtil.base64Encode(
            Blob.valueOf('Conteúdo de teste')
        );
        return fw;
    }

    /* ---------- TESTE PRINCIPAL ---------- */
    @IsTest
    static void testUploadDocuments_Success() {
        Case c = createCase();

        List<CaseDocumentUploaderController.FileWrapper> files =
            new List<CaseDocumentUploaderController.FileWrapper>{
                createFile('teste1.pdf'),
                createFile('teste2.pdf')
            };

        Test.startTest();
        CaseDocumentUploaderController.uploadDocuments(
            c.Id,
            'Relatório',
            'Descrição de teste',
            files
        );
        Test.stopTest();
    }

    /* ---------- SEM CASE ---------- */
    @IsTest
    static void testUploadDocuments_NullCase() {
        List<CaseDocumentUploaderController.FileWrapper> files =
            new List<CaseDocumentUploaderController.FileWrapper>{
                createFile('teste.pdf')
            };

        Test.startTest();
        CaseDocumentUploaderController.uploadDocuments(
            null,
            'Tipo',
            'Desc',
            files
        );
        Test.stopTest();
    }

    /* ---------- SEM FICHEIROS ---------- */
    @IsTest
    static void testUploadDocuments_EmptyFiles() {
        Case c = createCase();

        Test.startTest();
        CaseDocumentUploaderController.uploadDocuments(
            c.Id,
            'Tipo',
            'Desc',
            new List<CaseDocumentUploaderController.FileWrapper>()
        );
        Test.stopTest();

    }

    /* ---------- FICHEIRO INVÁLIDO ---------- */
    @IsTest
    static void testUploadDocuments_InvalidFileIgnored() {
        Case c = createCase();

        CaseDocumentUploaderController.FileWrapper invalidFile =
            new CaseDocumentUploaderController.FileWrapper();
        invalidFile.fileName = 'invalido.pdf';
        invalidFile.base64Data = null;

        Test.startTest();
        CaseDocumentUploaderController.uploadDocuments(
            c.Id,
            'Tipo',
            'Desc',
            new List<CaseDocumentUploaderController.FileWrapper>{ invalidFile }
        );
        Test.stopTest();
    }
}