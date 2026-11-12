package co.ias.soporte.service;

import co.ias.soporte.domain.Cliente;
import co.ias.soporte.domain.Gestion;
import co.ias.soporte.domain.Solicitud;
import co.ias.soporte.domain.SolicitudDto;
import co.ias.soporte.repository.GestionRepository;
import co.ias.soporte.repository.SolicitudRepository;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/** Test harness ejecutable sin JUnit ni dependencias externas. */
public final class SolicitudServiceTest {
    private static int passed;

    public static void main(String[] args) {
        run("solicitud existente y varias gestiones: toma la fecha máxima",
                SolicitudServiceTest::existingWithGestionesReturnsLatestDate);
        run("solicitud inexistente: lanza excepción de dominio",
                SolicitudServiceTest::missingSolicitudThrowsNotFound);
        run("solicitud sin gestiones: fecha de última gestión null",
                SolicitudServiceTest::emptyGestionesReturnsNullDate);
        run("cliente null: consulta no produce NullPointerException",
                SolicitudServiceTest::nullClienteIsHandled);
        run("gestiones con fecha null: se ignoran al calcular máximo",
                SolicitudServiceTest::nullGestionDateIsIgnored);
        System.out.println("RESULTADO: " + passed + " pruebas superadas.");
    }

    private static void existingWithGestionesReturnsLatestDate() {
        LocalDateTime older = LocalDateTime.of(2026, 11, 1, 10, 0);
        LocalDateTime latest = LocalDateTime.of(2026, 11, 5, 16, 30);
        SolicitudService service = serviceWith(
                Optional.of(new Solicitud(10L, "PENDIENTE", new Cliente("  Ana Pérez  "))),
                List.of(new Gestion(older), new Gestion(latest))
        );

        SolicitudDto dto = service.consultar(10L);
        equal("Ana Pérez", dto.nombreCliente(), "Debe recortar espacios del nombre.");
        equal(latest, dto.ultimaFechaGestion(), "Debe elegir la fecha máxima.");
        equal("PENDIENTE", dto.estado(), "Debe conservar el estado.");
    }

    private static void missingSolicitudThrowsNotFound() {
        SolicitudService service = serviceWith(Optional.empty(), List.of());
        expect(SolicitudNotFoundException.class, () -> service.consultar(999L));
    }

    private static void emptyGestionesReturnsNullDate() {
        SolicitudService service = serviceWith(
                Optional.of(new Solicitud(11L, "PENDIENTE", new Cliente("Luis"))),
                List.of()
        );
        SolicitudDto dto = service.consultar(11L);
        equal(null, dto.ultimaFechaGestion(), "Sin gestiones, la fecha debe ser null.");
    }

    private static void nullClienteIsHandled() {
        SolicitudService service = serviceWith(
                Optional.of(new Solicitud(12L, "PENDIENTE", null)),
                List.of()
        );
        SolicitudDto dto = service.consultar(12L);
        equal(null, dto.nombreCliente(), "Sin cliente, el nombre debe ser null.");
    }

    private static void nullGestionDateIsIgnored() {
        LocalDateTime valid = LocalDateTime.of(2026, 11, 10, 8, 0);
        SolicitudService service = serviceWith(
                Optional.of(new Solicitud(13L, "PENDIENTE", new Cliente(null))),
                List.of(new Gestion(null), new Gestion(valid))
        );
        SolicitudDto dto = service.consultar(13L);
        equal(valid, dto.ultimaFechaGestion(), "Debe ignorar fechas nulas.");
        equal(null, dto.nombreCliente(), "Nombre nulo debe quedar como null.");
    }

    private static SolicitudService serviceWith(
            Optional<Solicitud> solicitud,
            List<Gestion> gestiones
    ) {
        SolicitudRepository solicitudRepository = id -> solicitud;
        GestionRepository gestionRepository = id -> new ArrayList<>(gestiones);
        return new SolicitudService(solicitudRepository, gestionRepository);
    }

    private static void run(String description, Runnable test) {
        try {
            test.run();
            passed++;
            System.out.println("[OK] " + description);
        } catch (Throwable error) {
            System.err.println("[FAIL] " + description + " -> " + error.getMessage());
            error.printStackTrace();
            System.exit(1);
        }
    }

    private static void equal(Object expected, Object actual, String message) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            throw new AssertionError(message + " Esperado=" + expected + ", actual=" + actual);
        }
    }

    private static void expect(Class<? extends Throwable> expected, Runnable action) {
        try {
            action.run();
        } catch (Throwable actual) {
            if (expected.isInstance(actual)) {
                return;
            }
            throw new AssertionError("Se esperaba " + expected.getName()
                    + " pero se obtuvo " + actual.getClass().getName(), actual);
        }
        throw new AssertionError("Se esperaba la excepción " + expected.getName());
    }
}
