package co.ias.soporte.service;

import co.ias.soporte.domain.Cliente;
import co.ias.soporte.domain.Gestion;
import co.ias.soporte.domain.Solicitud;
import co.ias.soporte.domain.SolicitudDto;
import co.ias.soporte.repository.GestionRepository;
import co.ias.soporte.repository.SolicitudRepository;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

/** Lógica aislada propuesta para corregir el método del enunciado. */
public final class SolicitudService {
    private final SolicitudRepository solicitudRepository;
    private final GestionRepository gestionRepository;

    public SolicitudService(
            SolicitudRepository solicitudRepository,
            GestionRepository gestionRepository
    ) {
        this.solicitudRepository = Objects.requireNonNull(solicitudRepository);
        this.gestionRepository = Objects.requireNonNull(gestionRepository);
    }

    public SolicitudDto consultar(Long id) {
        if (id == null) {
            throw new IllegalArgumentException("El id de solicitud es obligatorio.");
        }

        // La ausencia se expresa como un error de dominio, no como null.
        Solicitud solicitud = solicitudRepository.findById(id)
                .orElseThrow(() -> new SolicitudNotFoundException(id));

        // La relación o el nombre pueden faltar; el DTO representa esa ausencia con null.
        String nombreCliente = Optional.ofNullable(solicitud.cliente())
                .map(Cliente::nombre)
                .map(String::trim)
                .filter(nombre -> !nombre.isEmpty())
                .orElse(null);

        // No asumir que el primer elemento es el más reciente: la lista puede venir
        // desordenada. Una lista vacía o fechas nulas producen fechaUltima = null.
        List<Gestion> gestiones = gestionRepository.findBySolicitudId(id);
        if (gestiones == null) {
            // Defensa temporal ante una implementación que rompa el contrato del repositorio.
            gestiones = List.of();
        }

        LocalDateTime fechaUltima = gestiones.stream()
                .filter(Objects::nonNull)
                .map(Gestion::fechaGestion)
                .filter(Objects::nonNull)
                .max(Comparator.naturalOrder())
                .orElse(null);

        return new SolicitudDto(
                solicitud.id(),
                nombreCliente,
                solicitud.estado(),
                fechaUltima
        );
    }
}
