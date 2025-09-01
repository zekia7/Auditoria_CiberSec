#!/usr/bin/env bash
# audit_linux_full_17.sh
# Auditoría Oracle Linux - Mantiene los 17 ítems solicitados
# Genera: carpeta de evidencias y reporte.txt
# Uso: sudo ./audit_linux_full_17.sh

set -u
IFS=$'\n\t'

timestamp="$(date +'%Y-%m-%d_%H-%M-%S')"
host="$(hostname -f 2>/dev/null || hostname)"
outdir="audit_${host}_${timestamp}"
rep="${outdir}/reporte.txt"

mkdir -p "${outdir}/evidencia"
touch "${rep}"

log() { printf "%s\n" "$*" | tee -a "${rep}"; }
hdr() { printf "\n\n===== %s =====\n" "$*" | tee -a "${rep}"; }
sub() { printf "\n--- %s ---\n" "$*" | tee -a "${rep}"; }

need_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "Este script debe ejecutarse como root (sudo)." >&2
    exit 1
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

need_root

log "Auditoría iniciada: ${timestamp}"
log "Host: ${host}"
log "Salida principal: ${rep}"
log "Evidencias: ${outdir}/evidencia"

###########################
# 1) Servicios
###########################
hdr "[1] Servicios (activos)"
if have systemctl; then
  systemctl list-units --type=service --state=running --no-pager | tee -a "${rep}"
  systemctl list-unit-files --type=service | tee "${outdir}/evidencia/services_unitfiles.txt" 2>/dev/null
  log "(Evidencia: ${outdir}/evidencia/services_unitfiles.txt)"
else
  log "systemctl no disponible"
fi

###########################
# 2) Versión del servidor
###########################
hdr "[2] Versión del servidor / Kernel / OS"
{
  echo "# /etc/os-release"
  cat /etc/os-release 2>/dev/null || true
  echo
  echo "# uname -a"
  uname -a
} | tee -a "${rep}"

###########################
# 3) Carpetas con permisos 777
###########################
hdr "[3] Carpetas con permisos 777"
{
  echo "Buscando directorios con permisos 0777 (limitará device mount / para performance)..."
  find / -xdev -type d -perm -000777 -print 2>/dev/null || true
} | tee "${outdir}/evidencia/permisos_777.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/permisos_777.txt)"

###########################
# 4) Puertos abiertos
###########################
hdr "[4] Puertos abiertos (lista de sockets en escucha)"
if have ss; then
  ss -tulpen | tee "${outdir}/evidencia/puertos_ss.txt" | tee -a "${rep}"
  log "(Evidencia: ${outdir}/evidencia/puertos_ss.txt)"
elif have netstat; then
  netstat -tulpen | tee "${outdir}/evidencia/puertos_netstat.txt" | tee -a "${rep}"
  log "(Evidencia: ${outdir}/evidencia/puertos_netstat.txt)"
else
  log "ss/netstat no disponibles"
fi

###########################
# 5) Espacio en disco duro
###########################
hdr "[5] Espacio en disco"
{
  df -hT
  echo
  df -i
} | tee "${outdir}/evidencia/df.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/df.txt)"

###########################
# 6) Rendimiento de la memoria
###########################
hdr "[6] Rendimiento de memoria y configuración de swap"
{
  free -h
  echo
  if have vmstat; then vmstat 1 5; else echo "vmstat no instalado"; fi
  echo
  echo "# swappiness"
  sysctl vm.swappiness 2>/dev/null || cat /proc/sys/vm/swappiness 2>/dev/null || true
} | tee "${outdir}/evidencia/mem_swap.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/mem_swap.txt)"

###########################
# 7) Usuarios locales
###########################
hdr "[7] Usuarios locales"
getent passwd | tee "${outdir}/evidencia/usuarios_passwd.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/usuarios_passwd.txt)"

###########################
# 8) Grupos de usuarios
###########################
hdr "[8] Grupos de usuarios"
getent group | tee "${outdir}/evidencia/grupos.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/grupos.txt)"

###########################
# 9) Usuarios dentro de cada grupo
###########################
hdr "[9] Usuarios dentro de cada grupo (miembros)"
{
  getent group | while IFS=: read -r gname x gid members; do
    printf "Grupo: %-20s | GID: %-6s | Miembros: %s\n" "$gname" "$gid" "${members:-(ninguno)}"
  done
} | tee "${outdir}/evidencia/grupos_miembros.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/grupos_miembros.txt)"

###########################
# 10) Usuarios con privilegios de sudo
###########################
hdr "[10] Usuarios con privilegios de sudo"
{
  echo "# sudoers (sin comentarios)"
  if [[ -f /etc/sudoers ]]; then
    sed -n '/^[^#]/p' /etc/sudoers 2>/dev/null || true
  fi
  echo
  echo "# /etc/sudoers.d/"
  if [[ -d /etc/sudoers.d ]]; then
    for f in /etc/sudoers.d/*; do
      [[ -f "$f" ]] || continue
      echo "== $f =="
      sed -n '/^[^#]/p' "$f" 2>/dev/null || true
    done
  fi
  echo
  echo "# Miembros del grupo wheel/sudo"
  getent group wheel || true
  getent group sudo || true
} | tee "${outdir}/evidencia/sudoers.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/sudoers.txt)"

###########################
# 11) Listado de IPtables
###########################
hdr "[11] Listado de IPtables"
if have iptables; then
  iptables -S | tee "${outdir}/evidencia/iptables_S.txt" | tee -a "${rep}"
  iptables -L -n -v | tee -a "${rep}" >> "${outdir}/evidencia/iptables_L.txt"
  log "(Evidencia: ${outdir}/evidencia/iptables_S.txt , ${outdir}/evidencia/iptables_L.txt)"
else
  log "iptables no instalado"
fi

###########################
# 12) Configuración de firewalls
###########################
hdr "[12] Configuración de firewalls"
if systemctl is-active --quiet firewalld 2>/dev/null && have firewall-cmd; then
  firewall-cmd --list-all --zone=public 2>/dev/null | tee "${outdir}/evidencia/firewalld_public.txt" | tee -a "${rep}"
  firewall-cmd --list-all-zones 2>/dev/null | tee -a "${rep}"
  log "(Evidencia: ${outdir}/evidencia/firewalld_public.txt)"
elif have ufw; then
  ufw status verbose | tee "${outdir}/evidencia/ufw_status.txt" | tee -a "${rep}"
  log "(Evidencia: ${outdir}/evidencia/ufw_status.txt)"
else
  log "No se detectó firewalld ni ufw; revisando reglas iptables (si existen)."
fi

###########################
# 13) Listado de actualizaciones pendientes del SO
###########################
hdr "[13] Actualizaciones pendientes del SO"
if have dnf; then
  dnf -q check-update 2>/dev/null | tee "${outdir}/evidencia/updates_dnf.txt" | tee -a "${rep}"
  dnf updateinfo summary 2>/dev/null | tee -a "${rep}"
  log "(Evidencia: ${outdir}/evidencia/updates_dnf.txt)"
elif have yum; then
  yum -q check-update 2>/dev/null | tee "${outdir}/evidencia/updates_yum.txt" | tee -a "${rep}"
  log "(Evidencia: ${outdir}/evidencia/updates_yum.txt)"
else
  log "dnf/yum no disponibles"
fi

###########################
# 14) Logs de auditoría activados/desactivados
###########################
hdr "[14] Estado de logs de auditoría (auditd)"
if have systemctl; then
  systemctl is-active --quiet auditd && log "auditd: ACTIVO" || log "auditd: INACTIVO o no instalado"
  if [[ -f /etc/audit/auditd.conf ]]; then
    sed -n '/^[^#]/p' /etc/audit/auditd.conf 2>/dev/null | tee "${outdir}/evidencia/auditd_conf.txt" | tee -a "${rep}"
    log "(Evidencia: ${outdir}/evidencia/auditd_conf.txt)"
  fi
  if [[ -d /etc/audit/rules.d ]]; then
    grep -H --line-number -v '^\s*#' /etc/audit/rules.d/* 2>/dev/null | tee "${outdir}/evidencia/audit_rules.txt" | tee -a "${rep}"
    log "(Evidencia: ${outdir}/evidencia/audit_rules.txt)"
  fi
else
  log "systemctl no disponible para comprobar auditd"
fi

###########################
# 15) Parámetros de contraseña (globales)
###########################
hdr "[15] Parámetros globales de contraseña"
{
  echo "# /etc/login.defs (relevantes)"
  egrep -i 'PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_MIN_LEN|PASS_WARN_AGE' /etc/login.defs 2>/dev/null || true
  echo
  echo "# PAM (password-auth / system-auth) - reglas relevantes"
  for f in /etc/pam.d/password-auth /etc/pam.d/system-auth; do
    [[ -f $f ]] && { echo "== $f =="; sed -n '/^[^#]/p' "$f"; echo; }
  done
} | tee "${outdir}/evidencia/password_global.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/password_global.txt)"

###########################
# 16) Ver si los parámetros de contraseña por usuario son robustos
###########################
hdr "[16] Robustez de parámetros de contraseña por usuario"
{
  printf "%-20s | %-12s | %-18s | %-10s | %-20s\n" "Usuario" "Estado" "Hash_algo" "PwdExpire" "ÚltimoAcceso"
  awk -F: '{print $1":"$3":"$7}' /etc/passwd | while IFS=: read -r u uid shell; do
    # Aplicar a usuarios "relevantes" (UID>=1000) y root
    if [[ "$uid" -ge 1000 || "$u" == "root" ]]; then
      # shell:
      user_shell="$(getent passwd "$u" | cut -d: -f7)"
      # passwd -S:
      pstat="$(passwd -S "$u" 2>/dev/null | awk '{print $2}' || echo "NA")"
      case "$pstat" in
        L) estado="Bloqueado" ;;
        P) estado="Activo" ;;
        NP) estado="ActivoSinPass" ;;
        *) estado="Desconocido" ;;
      esac
      # hash algorithm from /etc/shadow 2nd field: starts with $6$ -> SHA-512, $5$->SHA-256, $1$->MD5
      shadow_hash="$(awk -F: -v u="$u" '$1==u{print $2}' /etc/shadow 2>/dev/null || echo "")"
      case "$shadow_hash" in
        \$6\$*) hashalgo="SHA-512" ;;
        \$5\$*) hashalgo="SHA-256" ;;
        \$1\$*) hashalgo="MD5 (débil)" ;;
        "") hashalgo="(sin hash / no aplicable)" ;;
        *) hashalgo="Otro/Desconocido" ;;
      esac
      # Password expires:
      pexpire="$(chage -l "$u" 2>/dev/null | awk -F: '/Password expires/{print $2}' | sed 's/^ //')"
      [[ -z "$pexpire" ]] && pexpire="(no disponible)"
      # Last access:
      lastacc="$(lastlog -u "$u" 2>/dev/null | awk 'NR==2{print $4,$5,$6,$7}' || echo "Never")"
      printf "%-20s | %-12s | %-18s | %-10s | %-20s\n" "$u" "$estado" "$hashalgo" "$pexpire" "$lastacc"
    fi
  done
} | tee "${outdir}/evidencia/password_robustez.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/password_robustez.txt)"

###########################
# 17) Usuarios genéricos / default
###########################
hdr "[17] Usuarios genéricos / default (sospechosos)"
{
  echo "Cuentas con nombres comunes genéricos (guest/test/admin/user/etc):"
  egrep -i '^(guest|test|admin|user|demo|support|oracle|postgres|mysql|ftp|www-data|apache|nobody)' /etc/passwd || echo "(No se detectaron coincidencias por patrón)"
  echo
  echo "Cuentas con shell nologin/false (consideradas inactivas):"
  awk -F: '($7~/nologin|false/){printf "%-20s | UID: %-5s | Shell: %s\n", $1,$3,$7}' /etc/passwd || true
  echo
  echo "Cuentas con UID < 1000 (system/service accounts):"
  awk -F: '($3<1000){printf "%-20s | UID: %-5s | GECOS: %s\n", $1,$3,$5}' /etc/passwd || true
} | tee "${outdir}/evidencia/usuarios_genericos.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/usuarios_genericos.txt)"

###########################
# CONTROLES ADICIONALES (no eliminados — estaban en el script previo)
###########################
hdr "Controles adicionales (integridad, SELinux/SSH/cron/NTP/kmod)"
# SELinux / AppArmor
sub "SELinux / AppArmor"
if have getenforce; then
  getenforce 2>/dev/null | tee -a "${rep}"
  sestatus 2>/dev/null | tee -a "${rep}"
elif have aa-status; then
  aa-status 2>/dev/null | tee -a "${rep}"
else
  echo "No SELinux/AppArmor detectado" | tee -a "${rep}"
fi

# SSH config
sub "SSH - configuracion"
if [[ -f /etc/ssh/sshd_config ]]; then
  grep -E '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|Port|PermitEmptyPasswords|PermitUserEnvironment|AllowUsers|AllowGroups|MaxAuthTries)' /etc/ssh/sshd_config 2>/dev/null | tee -a "${rep}"
  sed -n '/^[^#]/p' /etc/ssh/sshd_config 2>/dev/null | tee "${outdir}/evidencia/ssh_config.txt" 2>/dev/null
  log "(Evidencia: ${outdir}/evidencia/ssh_config.txt)"
else
  echo "sshd_config no encontrado" | tee -a "${rep}"
fi

# Cron
sub "Cron jobs"
{
  echo "# /etc/crontab"
  [[ -f /etc/crontab ]] && cat /etc/crontab || echo "(no existe /etc/crontab)"
  echo
  for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d; do
    [[ -d $d ]] && { echo "== $d =="; ls -l "$d" || true; echo; }
  done
  echo
  echo "# crontabs por usuario (UID>=1000)"
  awk -F: '($3>=1000 && $7!~/(nologin|false)$/){print $1}' /etc/passwd | while read -r u; do
    echo "-- crontab de $u --"
    crontab -u "$u" -l 2>/dev/null || echo "(sin crontab)"
  done
} | tee "${outdir}/evidencia/cron_all.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/cron_all.txt)"

# Integridad de binarios (rpm -Va truncado + full file)
sub "Integridad de binarios (rpm -Va - salida truncada en pantalla, completa en evidencia)"
if have rpm; then
  rpm -Va 2>/dev/null | head -n 300 | tee -a "${rep}"
  rpm -Va 2>/dev/null > "${outdir}/evidencia/rpm_verify_full.txt" || true
  log "(Evidencia: ${outdir}/evidencia/rpm_verify_full.txt)"
else
  echo "rpm no disponible" | tee -a "${rep}"
fi

# NTP / chrony
sub "Sincronización de tiempo (NTP/chrony)"
timedatectl 2>/dev/null | tee -a "${rep}"
if systemctl is-active --quiet chronyd 2>/dev/null && have chronyc; then
  chronyc sources -v 2>/dev/null | tee -a "${rep}"
fi

# Kernel modules
sub "Módulos kernel cargados"
lsmod 2>/dev/null | tee "${outdir}/evidencia/lsmod.txt" | tee -a "${rep}"
log "(Evidencia: ${outdir}/evidencia/lsmod.txt)"

###########################
# Resumen rápido final
###########################
hdr "Resumen rápido y puntos críticos"
{
  echo "- Usuarios con sudo: $(grep -rE '^[^#].*ALL=\(ALL\)' /etc/sudoers /etc/sudoers.d 2>/dev/null | wc -l || true)"
  echo "- Directorios 0777: $(grep -v '^Escaneando' "${outdir}/evidencia/permisos_777.txt" 2>/dev/null | sed '/^\s*$/d' | wc -l || true)"
  if have ss; then
    echo "- Puertos en escucha: $(ss -tuln | sed 1,1d | wc -l || true)"
  else
    echo "- Puertos en escucha: (ss/netstat no disponible)"
  fi
  echo "- auditd: $(systemctl is-active auditd 2>/dev/null || echo 'no instalado/inactivo')"
  echo "- SELinux (getenforce): $( (have getenforce && getenforce) || 'N/A')"
} | tee -a "${rep}"

log "Auditoría finalizada. Revise ${rep} y la carpeta ${outdir}/evidencia para todas las salidas y evidencias."

exit 0
