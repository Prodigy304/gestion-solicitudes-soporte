package co.ias.soporte.repository;

import co.ias.soporte.domain.Solicitud;
import java.util.Optional;

public interface SolicitudRepository {
    Optional<Solicitud> findById(Long id);
}
