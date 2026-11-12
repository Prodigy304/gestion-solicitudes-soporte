package co.ias.soporte.repository;

import co.ias.soporte.domain.Gestion;
import java.util.List;

public interface GestionRepository {
    /** El contrato del repositorio es retornar una lista vacía, nunca null. */
    List<Gestion> findBySolicitudId(Long solicitudId);
}
