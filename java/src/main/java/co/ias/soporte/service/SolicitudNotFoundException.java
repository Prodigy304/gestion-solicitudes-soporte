package co.ias.soporte.service;

public final class SolicitudNotFoundException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public SolicitudNotFoundException(Long id) {
        super("No existe una solicitud con el identificador indicado: " + id);
    }
}
