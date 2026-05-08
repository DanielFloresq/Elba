import { LightningElement, api, track } from "lwc";
import GetComentarios from "@salesforce/apex/ElbaChatMessageOrderController.GetComentarios";
import PostComentario from "@salesforce/apex/ElbaChatMessageOrderController.PostComentario";
import FavoritoComentario from "@salesforce/apex/ElbaChatMessageOrderController.FavoritoComentario";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import Id from "@salesforce/user/Id";
export default class ElbaChatMessageOrderComponent extends NavigationMixin(
    LightningElement
) {
    @api recordId;

    allActivities;
    message = '';
    userId = Id;
    @track emailsFiles = [];
    comentarioId;
    @track arrayForImage = [];
    @track disable;
    showSpinner = false;

    get acceptedFormatsString() {
        return this.acceptedFormats.join(",");
    }

    get hasPendingFiles() {
        return this.emailsFiles.length > 0;
    }

    getActivities() {
        GetComentarios({ OrderId: this.recordId, UserId: this.userId }).then(
            (data) => {
                this.allActivities = this.formatActivities(data);
            }
        );
        console.log(this.userId);
    }

    connectedCallback() {
        this.getActivities();
        this.updateDisableState();
    }

    handleClick() {
        console.log(this.message);
        this.showSpinner = true;
        this.disable = true;
        if ((this.message && this.message.trim()) || this.arrayForImage.length) {
            PostComentario({
                OrderId: this.recordId,
                Message: this.message,
                files: this.arrayForImage
            }).then((data) => {
                console.log(data);
                if (data) {
                    this.getActivities();
                    this.message = null;
                    this.arrayForImage = [];
                    this.emailsFiles = [];
                }
                this.showSpinner = false;
                this.updateDisableState();
            });
        }
    }

    onClickBottomNotFavorite(e) {
        console.debug(e.target.value);
        this.showSpinner = true;
        this.comentarioId = e.target.value;
        FavoritoComentario({ ComentarioId: this.comentarioId }).then((data) => {
            if (data != null) {
                this.getActivities();
                if (data == true) {
                    const evt = new ShowToastEvent({
                        title: "Alerta",
                        message: "Comentário adicionado aos Favoritos!",
                        variant: "info"
                    });
                    this.dispatchEvent(evt);
                } else {
                    const evt = new ShowToastEvent({
                        title: "Alerta",
                        message: "Comentário retirado dos Favoritos!",
                        variant: "info"
                    });
                    this.dispatchEvent(evt);
                }
                this.showSpinner = false;
            }
        });
    }

    acceptedFormats = [".jpg", ".jpeg", ".gif", ".png"];
    handleUploadFile(event) {
        if (event.detail.files && event.detail.files.length) {
            const imgFile = event.detail.files[0];
            // you could check the file size (imgFile.size)

            this.showSpinner = true;

            const fileReader = new FileReader();
            fileReader.onloadend = () => {
                let result = fileReader.result;
                console.log(result);
                const base64 = "base64,";
                const i = result.indexOf(base64) + base64.length;
                let base64Body = result.substring(i);
                console.log(base64Body);
                const apexParams = {
                    fileName: imgFile.name,
                    fileType: imgFile.type,
                    filesize: imgFile.size,
                    fileBody: base64Body
                };
                console.log(base64Body);

                //base64:image/pnb
                this.arrayForImage.push(apexParams);
                this.arrayForImage = [...this.arrayForImage];
                console.log(this.arrayForImage);

                /*Object para Pill*/
                let fileFormat;
                if (imgFile.type.includes("image")) {
                    fileFormat = "image";
                } else {
                    const slashIndex = imgFile.type.indexOf("/"); // Find the index of '/'
                    fileFormat = imgFile.type.substr(slashIndex + 1);
                }

                if (fileFormat === "x-msdownload") {
                    fileFormat = "exe";
                }

                const obj = {
                    id: `${imgFile.name}-${imgFile.size}-${Date.now()}`,
                    name: imgFile.name,
                    sizeLabel: `${(imgFile.size / 1048576).toFixed(3)} MB`,
                    iconName: "doctype:" + fileFormat,
                    previewUrl: result,
                    isImage: imgFile.type.includes("image")
                };
                this.emailsFiles = [...this.emailsFiles, obj];
                console.log(obj);

                event.target.value = null;
                this.showSpinner = false; // this should be in the then() of apex call
                this.updateDisableState();
            };

            fileReader.readAsDataURL(imgFile);
        }
    }

    HandleChange(e) {
        console.log(this.message);
        this.message = e.detail.value;
        this.updateDisableState();
    }

    onClickFile(e) {
        var fileId = e.currentTarget.dataset.fileid;

        console.log(fileId);
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                objectApiName: "ContentDocument",
                actionName: "view",
                recordId: fileId
            }
        });
    }

    handleToItemRemoveEmail(event) {
        const index = event.detail.index;
        this.emailsFiles.splice(index, 1);
        this.arrayForImage.splice(index, 1);
        this.emailsFiles = [...this.emailsFiles];
        this.arrayForImage = [...this.arrayForImage];
        this.updateDisableState();
    }

    handleRemovePendingFile(event) {
        const fileId = event.currentTarget.dataset.fileid;
        const index = this.emailsFiles.findIndex((file) => file.id === fileId);

        if (index === -1) {
            return;
        }

        this.emailsFiles.splice(index, 1);
        this.arrayForImage.splice(index, 1);
        this.emailsFiles = [...this.emailsFiles];
        this.arrayForImage = [...this.arrayForImage];
        this.updateDisableState();
    }

    updateDisableState() {
        this.disable = !(this.message && this.message.trim()) && !this.arrayForImage.length;
    }

    resolvePillIcon(type) {
        const t = (type || "").toLowerCase();
        if (["jpg", "jpeg", "png", "gif", "image"].includes(t)) return "utility:image";
        if (t === "pdf") return "doctype:pdf";
        if (["xls", "xlsx", "csv"].includes(t)) return "doctype:excel";
        if (["doc", "docx"].includes(t)) return "doctype:word";
        if (["ppt", "pptx"].includes(t)) return "doctype:ppt";
        if (t === "zip") return "doctype:zip";
        return "utility:attach";
    }

    formatActivities(data) {
        if (!data || !data.length) {
            return [];
        }

        return data.map((activity) => {
            const files = (activity.Files || []).map((f) => ({
                ...f,
                pillIcon: this.resolvePillIcon(f.Type)
            }));

            return {
                ...activity,
                Files: files
            };
        });
    }
}