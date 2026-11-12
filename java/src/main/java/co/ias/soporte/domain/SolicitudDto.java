package co.ias.soporte.domain;

import java.time.LocalDateTime;

/**
 * DTO de respuesta simplificado para el ejercicio.
 * ultimaFechaGestion y nombreCliente pueden ser null si no hay datos relacionados.
 */
public record SolicitudDto(
        Long id,
        String nombreCliente,
        String estado,
        LocalDateTime ultimaFechaGestion
) {
}
