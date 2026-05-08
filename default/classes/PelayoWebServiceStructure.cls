/**
 * @description       : Apex structure to represent the JSON for claims, policy, and assignments (siniestros, póliza y encargos).
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 09-04-2026
 * @last modified by  : Daniel Flores
 **/
public class PelayoWebServiceStructure {
    
    public class body {
        public Poliza poliza;
        public Siniestro siniestro;
        public Encargo encargo;
    }   
    public class Poliza {
        public String identificadorPoliza;
        public String canalOrigen;
        public Date fechaEfecto;
        public Boolean polizaMediada;
        public String identificadorMediador;
        public Boolean clienteVIP;
        public String nombreMediador;
        public String direccionRiesgo;
        public String tipoVia;
        public String nombreVia;
        public String numero;
        public String escalera;
        public String piso;
        public String puerta;
        public String codigoPostal;
        public String poblacion;
        public String provincia;
        public Decimal capitalContinente;
        public Decimal capitalContenido;
        public Decimal capitalRC;
        public String nombreAsegurado;
        public String nombre;
        public String apellido1;
        public String apellido2;
        public String tipoIdentificador;
        public String identificador;
        public String email;
        public String movil;
        public String otrosContactos;
        public String idiomaPreferido;
        public String ramo;
        public String anioConstruccion;
        public String anioUltimaReforma;
    }
    public class Siniestro {
        public String cuadranteExponencial;
        public String referenciaSiniestroAseguradora;
        public String descripcionDeclarante;
        public String nombreDeclarante;
        public String nombrePersonaContacto;
        public String parentescoAsegurado;
        public String telefonoMovilPersonaContacto;
        public String observacionesPersonaContacto;
        public String descripcionSiniestro;
        public String cuestionario;
        public Date fechaDeclaracion;
        public Date fechaOcurrencia;
        public String identificadorCausa;
        public String identificadorSubcausa;
        public Boolean organoVitalAfectado;
        public String movil;
        public Boolean quiereSMS;
        public String email;
        public Boolean quiereEmail;
        public Decimal franquicia;
        public Decimal franquiciaConsumida;
        public String identificadorTipoSiniestro;
        public Decimal provisionActual;
        public Boolean servicioAsistencia;
        public String tipoSituacion;
        public Boolean urgente;
        public List<String> danosOcasionados;
        public String nombreTramitador;
        public String emailTramitador;
        public List<String> marcadores;
        public List<StakeHolder> listaImplicados;
        public List<GarantiaDetalle> garantiasSiniestro;
        public List<GarantiaDetalle> garantiasPoliza;
    }
    public class StakeHolder {
        public String nombre;
        public String apellido1;
        public String apellido2;
        public String tipoImplicado;
        public String comentarios;
        public String email;
        public String horaInicioContactoMovilPrincipal;
        public String horaFinContactoMovilPrincipal;
        public String horaInicioContactoMovilSecundario;
        public String horaFinContactoMovilSecundario;
        public String horaInicioContactoFijo;
        public String horaFinContactoFijo;
        public String movilPrincipal;
        public String movilSecundario;
        public String telefonoFijo;
        public String descripcionCompaniaAseguradora;
        public String codigoPostal;
        public String escalera;
        public String letra;
        public String nombreVia;
        public String numero;
        public String pais;
        public String piso;
        public String poblacion;
        public String provincia;
        public String tipoVia;
        public Date fechaBaja;
        public String identificadorCompaniaAseguradora;
        public String identificador;
        public String tipoIdentificador;
        public String numeroAsegurado;
        public String referenciaSiniestroCompaniaContraria;
    }
    public class Encargo {
        public String referenciaEncargoAseguradora;
        public String tipoProvider;
        public Date fechaAsignacion;
        public Time horaAsignacion;
        public String tipoServicio;
        public String gremio;
        public String referenciaProveedor;
        public String comentario;
        public Boolean urgente;
        public String nombrePerito;
        public String emailPerito;
        public String telefonoPerito;
        public String movilPerito;
        public String referenciaperito;
        public Date fechaalta;
        public Date fechacierre;
        public String estadoperitacion;
        public String tipoperitacion;
        public String motivoaltaperito;
    }
    public class Garantia {
        public Integer codCobertura;
        public String nomCobertura;
        public Decimal limCapital;
        public String franquicia;
        public Boolean siniestrable;
    }

    public class GarantiaDetalle {
        public String garantia;
        public String cobertura;
        public String capital;
        public String limite;
        public Boolean existefranquicia;
        public String importefranquicia;
        public String franquiciaConsumida;
        public String limiteusos;
        public String usosconsumidos;
        public Boolean esprimerriesgo;
    }
}