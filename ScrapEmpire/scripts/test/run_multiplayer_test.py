#!/usr/bin/env python3
"""
Runner per test multiplayer headless.
Avvia host e client come processi Godot separati, raccoglie log e verifica risultati.
"""

import subprocess
import time
import json
import os
import sys
import signal
from pathlib import Path
from typing import Optional, Dict, List

# Configurazione
GODOT_PATH = r"C:\Users\ASUS\Desktop\scrap game\tools\Godot_v4.3-stable_win64.exe"
PROJECT_PATH = r"C:\Users\ASUS\Desktop\scrap game\ScrapEmpire"
TEST_SCENE = "res://scripts/test/test_multiplayer_integration.tscn"  # Scena di test
HEADLESS_ARGS = ["--headless", "--no-window"]
TEST_TIMEOUT = 60  # secondi
PORT = 24567

class TestRunner:
    def __init__(self):
        self.project_path = Path(PROJECT_PATH)
        self.godot_path = Path(GODOT_PATH)
        self.host_proc: Optional[subprocess.Popen] = None
        self.client_proc: Optional[subprocess.Popen] = None
        self.results: Dict = {}

    def check_prerequisites(self) -> bool:
        """Verifica che Godot e progetto esistano."""
        if not self.godot_path.exists():
            print(f"ERRORE: Godot non trovato in {self.godot_path}")
            return False
        if not (self.project_path / "project.godot").exists():
            print(f"ERRORE: Progetto non trovato in {self.project_path}")
            return False
        print(f"[OK] Godot: {self.godot_path}")
        print(f"[OK] Progetto: {self.project_path}")
        return True

    def create_test_scene(self) -> bool:
        """Verifica che la scena di test esista (già creata)."""
        scene_path = self.project_path / "scripts" / "test" / "test_multiplayer_integration.tscn"
        if not scene_path.exists():
            print(f"ERRORE: Scena test non trovata: {scene_path}")
            return False
        print(f"[OK] Scena test trovata: {scene_path}")
        return True

    def run_godot(self, args: List[str], role: str) -> subprocess.Popen:
        """Avvia processo Godot con argomenti specificati."""
        # Il primo argomento deve essere la scena di test, poi gli argomenti custom
        scene_path = "res://scripts/test/test_multiplayer_integration.tscn"
        cmd = [str(self.godot_path)] + HEADLESS_ARGS + ["--path", str(self.project_path), scene_path] + args
        print(f"[{role}] Avvio: {' '.join(cmd)}")

        # Log separati per host e client
        log_dir = self.project_path / "test_logs"
        log_dir.mkdir(exist_ok=True)
        log_file = log_dir / f"{role}_{int(time.time())}.log"

        proc = subprocess.Popen(
            cmd,
            stdout=open(log_file, 'w'),
            stderr=subprocess.STDOUT,
            cwd=str(self.project_path),
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == 'nt' else 0
        )
        print(f"[{role}] PID: {proc.pid}, Log: {log_file}")
        return proc

    def run_test(self, mismatch_type: Optional[str] = None) -> Dict:
        """Esegue test completo: avvia host, aspetta, avvia client, verifica."""
        print("\n" + "="*60)
        if mismatch_type:
            print(f"TEST MISMATCH: {mismatch_type}")
        else:
            print("TEST COMPLETO: Host + Client")
        print("="*60)

        # Avvia host
        host_args = ["--host"]
        if mismatch_type:
            host_args.extend(["--mismatch", mismatch_type])
        self.host_proc = self.run_godot(host_args, "HOST")

        # Aspetta che host sia pronto (dà tempo di bindare la porta)
        time.sleep(3)

        # Avvia client
        client_args = ["--client"]
        if mismatch_type:
            client_args.extend(["--mismatch", mismatch_type])
        self.client_proc = self.run_godot(client_args, "CLIENT")

        # Monitora processi
        start_time = time.time()
        host_done = False
        client_done = False
        host_exit_code = None
        client_exit_code = None

        while time.time() - start_time < TEST_TIMEOUT:
            # Controlla host
            if not host_done and self.host_proc.poll() is not None:
                host_exit_code = self.host_proc.returncode
                host_done = True
                print(f"[HOST] Terminato con exit code: {host_exit_code}")

            # Controlla client
            if not client_done and self.client_proc.poll() is not None:
                client_exit_code = self.client_proc.returncode
                client_done = True
                print(f"[CLIENT] Terminato con exit code: {client_exit_code}")

            if host_done and client_done:
                break

            time.sleep(0.5)

        # Timeout: termina processi rimasti
        if not host_done:
            print("[HOST] Timeout - terminazione forzata")
            self.terminate_process(self.host_proc, "HOST")
            host_exit_code = -1

        if not client_done:
            print("[CLIENT] Timeout - terminazione forzata")
            self.terminate_process(self.client_proc, "CLIENT")
            client_exit_code = -1

        # Leggi report JSON
        self.collect_reports()

        # Determina risultato
        success = (host_exit_code == 0 and client_exit_code == 0)
        if mismatch_type:
            # Per test mismatch, ci aspettiamo che SIA host che client passino (entrambi verificano rifiuto corretto)
            success = (host_exit_code == 0 and client_exit_code == 0)

        result = {
            "test_type": mismatch_type or "full",
            "host_exit_code": host_exit_code,
            "client_exit_code": client_exit_code,
            "success": success,
            "duration": time.time() - start_time
        }

        print(f"\nRisultato: {'PASS' if success else 'FAIL'}")
        print(f"Host exit: {host_exit_code}, Client exit: {client_exit_code}")
        return result

    def terminate_process(self, proc: Optional[subprocess.Popen], role: str):
        """Termina processo in modo pulito."""
        if proc and proc.poll() is None:
            try:
                if os.name == 'nt':
                    proc.send_signal(signal.CTRL_BREAK_EVENT)
                else:
                    proc.terminate()
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
            except Exception as e:
                print(f"[{role}] Errore terminazione: {e}")

    def collect_reports(self):
        """Raccoglie report JSON dai log."""
        log_dir = self.project_path / "test_logs"
        for report_file in log_dir.glob("test_report_*.json"):
            try:
                with open(report_file) as f:
                    data = json.load(f)
                    role = data.get("role", "unknown")
                    self.results[role] = data
                    print(f"[REPORT] {role}: {data['passed']}/{data['total_tests']} passati")
            except Exception as e:
                print(f"[REPORT] Errore lettura {report_file}: {e}")

    def cleanup(self):
        """Pulizia processi."""
        for proc, role in [(self.host_proc, "HOST"), (self.client_proc, "CLIENT")]:
            if proc and proc.poll() is None:
                self.terminate_process(proc, role)

    def run_all_tests(self) -> List[Dict]:
        """Esegue suite completa di test."""
        all_results = []

        # Test 1: Flusso completo compatibile
        print("\n>>> TEST 1: Flusso completo (compatibile)")
        result = self.run_test()
        all_results.append(result)
        self.cleanup()
        time.sleep(2)

        # Test 2: Protocol mismatch
        print("\n>>> TEST 2: Protocol version mismatch")
        result = self.run_test("protocol")
        all_results.append(result)
        self.cleanup()
        time.sleep(2)

        # Test 3: Build ID mismatch
        print("\n>>> TEST 3: Build ID mismatch")
        result = self.run_test("build")
        all_results.append(result)
        self.cleanup()
        time.sleep(2)

        # Test 4: Content hash mismatch
        print("\n>>> TEST 4: Content hash mismatch")
        result = self.run_test("hash")
        all_results.append(result)
        self.cleanup()

        return all_results


def main():
    runner = TestRunner()

    if not runner.check_prerequisites():
        sys.exit(1)

    if not runner.create_test_scene():
        sys.exit(1)

    try:
        results = runner.run_all_tests()

        # Summary
        print("\n" + "="*60)
        print("SUMMARY")
        print("="*60)
        for r in results:
            status = "PASS" if r["success"] else "FAIL"
            print(f"  [{status}] {r['test_type']}: host={r['host_exit_code']}, client={r['client_exit_code']}")

        # Overall success
        all_passed = all(r["success"] for r in results)
        print(f"\nOverall: {'ALL TESTS PASSED' if all_passed else 'SOME TESTS FAILED'}")

        # Salva summary
        summary_file = runner.project_path / "test_logs" / "test_summary.json"
        with open(summary_file, 'w') as f:
            json.dump({
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                "results": results,
                "all_passed": all_passed
            }, f, indent=2)
        print(f"Summary salvato: {summary_file}")

        sys.exit(0 if all_passed else 1)

    except KeyboardInterrupt:
        print("\nInterrotto dall'utente")
        runner.cleanup()
        sys.exit(130)
    except Exception as e:
        print(f"Errore: {e}")
        runner.cleanup()
        sys.exit(1)


if __name__ == "__main__":
    main()