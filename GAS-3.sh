#!/bin/bash

# Colores ANSI
BLUE="\e[1;34m"
GREEN="\e[1;32m"
RED="\e[1;31m"
YELLOW="\e[1;33m"
NC="\e[0m" # No Color

# Ruta del archivo de salida
OUTPUT_DIR="$(dirname "$0")"
OUTPUT_FILE="$OUTPUT_DIR/auditoria_oracle_linux_$(date +%Y%m%d_%H%M%S).log"

# Guardar también los colores en el log
exec > >(tee -a "$OUTPUT_FILE") 2>&1

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} AUDITORÍA DE SERVIDOR ORACLE LINUX ${NC}"
echo -e " Fecha: $(date)"
echo -e " Archivo generado: $OUTPUT_FILE"
echo -e "${BLUE}========================================${NC}"

# 1. Servicios activos
echo -e "\n${BLUE}[1] Servicios activos:${NC}"
systemctl list-units --type=service --state=running

# 2. Versión del servidor
echo -e "\n${BLUE}[2] Versión del servidor:${NC}"
cat /etc/os-release

# 3. Carpetas con permisos 777
echo -e "\n${BLUE}[3] Carpetas con permisos 777:${NC}"
find / -type d -perm 0777 2>/dev/null

# 4. Puertos abiertos
echo -e "\n${BLUE}[4] Puertos abiertos:${NC}"
ss -tuln

# 5. Espacio en disco
echo -e "\n${BLUE}[5] Espacio en disco:${NC}"
df -h

# 6. Rendimiento de la memoria y swap
echo -e "\n${BLUE}[6] Rendimiento de memoria y configuración de swap:${NC}"
free -h
swapon --show

# 7. Usuarios locales
echo -e "\n${BLUE}[7] Usuarios locales en el sistema:${NC}"
cut -d: -f1 /etc/passwd

# 8. Grupos de usuarios
echo -e "\n${BLUE}[8] Grupos de usuarios:${NC}"
cut -d: -f1 /etc/group

# 9. Usuarios dentro de cada grupo
echo -e "\n${BLUE}[9] Usuarios en cada grupo:${NC}"
getent group | while IFS=: read -r group _ gid members; do
    echo -e "${GREEN}Grupo:${NC} $group"
    echo "Usuarios: $members"
    echo "-----------------------------"
done

# 10. Usuarios con privilegios sudo
echo -e "\n${BLUE}[10] Usuarios con privilegios de sudo:${NC}"
getent group sudo || getent group wheel

# 11. Listado de iptables
echo -e "\n${BLUE}[11] Reglas de iptables:${NC}"
iptables -L -n -v 2>/dev/null || echo -e "${YELLOW}iptables no está disponible.${NC}"

# 12. Configuración de firewall (firewalld si aplica)
echo -e "\n${BLUE}[12] Configuración del firewall:${NC}"
if systemctl is-active --quiet firewalld; then
    firewall-cmd --list-all
else
    echo -e "${YELLOW}Firewalld no está activo.${NC}"
fi

# 13. Actualizaciones pendientes
echo -e "\n${BLUE}[13] Actualizaciones pendientes:${NC}"
if dnf check-update; then
    echo -e "${YELLOW}Se encontraron actualizaciones disponibles.${NC}"
else
    echo -e "${GREEN}No se encontraron actualizaciones pendientes.${NC}"
fi

# 14. Logs de auditoría (auditd)
echo -e "\n${BLUE}[14] Estado de logs de auditoría:${NC}"
systemctl is-active auditd && echo -e "${GREEN}Auditd está activo.${NC}" || echo -e "${RED}Auditd NO está activo.${NC}"

# 15. Parámetros de contraseña globales
echo -e "\n${BLUE}[15] Parámetros de contraseñas (login.defs):${NC}"
grep -E "PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE|PASS_MIN_LEN" /etc/login.defs

# 16. Parámetros de contraseñas por usuario (chage)
echo -e "\n${BLUE}[16] Parámetros de contraseñas por usuario (detalles con chage):${NC}"
for user in $(cut -d: -f1 /etc/passwd); do
    echo "---------------------------------------------"
    echo -e "${GREEN}Usuario:${NC} $user"
    chage -l $user 2>/dev/null
done

# 17. Usuarios genéricos o default
echo -e "\n${BLUE}[17] Usuarios genéricos o por defecto:${NC}"
grep -E "^(root|guest|test|user|admin)" /etc/passwd || echo -e "${GREEN}No se detectaron usuarios genéricos comunes.${NC}"

# 18. Estado de usuarios (activos/inactivos)
echo -e "\n${BLUE}[18] Estado de usuarios (activos/inactivos):${NC}"
for user in $(cut -d: -f1 /etc/passwd); do
    passwd -S $user 2>/dev/null
done

# 19. Verificar las Tareas programadas
echo -e "\n${BLUE}[19] Tareas programadas (cron jobs):${NC}"
crontab -l 2>/dev/null || echo -e "${YELLOW}No hay tareas en crontab para root.${NC}"
ls -lah /etc/cron* 2>/dev/null

# 20. Revisar el archivo de SSH
echo -e "\n${BLUE}[20] Configuración de SSH:${NC}"
if systemctl is-active --quiet sshd; then
    echo -e "${GREEN}SSHD está activo.${NC}"
    grep -E "Port|PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null
else
    echo -e "${RED}SSHD no está activo.${NC}"
fi

# 21. Configuración del Servidor NTP
echo -e "\n${BLUE}[21] Configuración NTP:${NC}"
if systemctl is-active --quiet chronyd; then
    echo -e "${GREEN}Chrony está activo.${NC}"
    chronyc sources -v 2>/dev/null
elif systemctl is-active --quiet ntpd; then
    echo -e "${GREEN}NTPd está activo.${NC}"
    ntpq -p 2>/dev/null
else
    echo -e "${RED}No se detectó un servicio NTP activo.${NC}"
fi

# 22. Hora y sincronización
echo -e "\n${BLUE}[22] Hora y sincronización:${NC}"
timedatectl

# 23. Reglas de acceso / Firewalls
echo -e "\n${BLUE}[23] Reglas de acceso (iptables + firewalld):${NC}"
iptables -S 2>/dev/null
if systemctl is-active --quiet firewalld; then
    firewall-cmd --list-all
fi

# 24. Módulos del kernel cargados y versiones
echo -e "\n${BLUE}[24] Módulos del kernel cargados y versiones:${NC}"
lsmod | head -20
echo -e "${YELLOW}Versiones del kernel instaladas:${NC}"
rpm -q kernel

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE} FIN DE AUDITORÍA ${NC}"
echo -e " Archivo guardado en: $OUTPUT_FILE"
echo -e "${BLUE}========================================${NC}"
