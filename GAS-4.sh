#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # Sin color

echo -e "${BLUE}==================== INICIO DE AUDITORÍA ====================${NC}"

# 1. Usuarios con acceso
echo -e "\n${BLUE}[1] Usuarios con acceso:${NC}"
cat /etc/passwd | awk -F: '{print $1}' | tee usuarios.log

# 2. Últimos accesos
echo -e "\n${BLUE}[2] Últimos accesos:${NC}"
last -n 5 | tee ultimos_accesos.log

# 3. Procesos activos
echo -e "\n${BLUE}[3] Procesos activos:${NC}"
ps -eo user,pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 10 | tee procesos.log

# 4. Espacio en disco
echo -e "\n${BLUE}[4] Espacio en disco:${NC}"
df -h | tee espacio.log

# 5. Uso de memoria
echo -e "\n${BLUE}[5] Uso de memoria:${NC}"
free -h | tee memoria.log

# 6. Swap
echo -e "\n${BLUE}[6] Estado de la swap:${NC}"
swapon --show | tee swap.log

# 7. Módulos del kernel
echo -e "\n${BLUE}[7] Módulos del kernel:${NC}"
lsmod | head -n 10 | tee modulos_kernel.log

# 8. Servicios activos
echo -e "\n${BLUE}[8] Servicios activos:${NC}"
systemctl list-units --type=service --state=running | tee servicios.log

# 9. Puertos abiertos
echo -e "\n${BLUE}[9] Puertos abiertos:${NC}"
ss -tulnp | tee puertos.log

# 10. Firewall
echo -e "\n${BLUE}[10] Estado del firewall:${NC}"
systemctl is-active firewalld | tee firewall.log

# 11. SELinux
echo -e "\n${BLUE}[11] Estado de SELinux:${NC}"
getenforce | tee selinux.log

# 12. Cron jobs
echo -e "\n${BLUE}[12] Tareas programadas (cron):${NC}"
crontab -l 2>/dev/null | tee cronjobs.log

# 13. Logs críticos
echo -e "\n${BLUE}[13] Últimos logs críticos:${NC}"
journalctl -p 3 -n 20 | tee logs_criticos.log

# 14. Usuarios sudoers
echo -e "\n${BLUE}[14] Usuarios sudoers:${NC}"
getent group sudo | awk -F: '{print $4}' | tee sudoers.log

# 15. Versión del sistema
echo -e "\n${BLUE}[15] Versión del sistema:${NC}"
cat /etc/os-release | tee version.log

# 16. Kernel
echo -e "\n${BLUE}[16] Versión del kernel:${NC}"
uname -r | tee kernel.log

# 17. Conexiones activas
echo -e "\n${BLUE}[17] Conexiones activas:${NC}"
ss -s | tee conexiones.log

# 18. Actualizaciones disponibles
echo -e "\n${BLUE}[18] Actualizaciones disponibles:${NC}"
dnf check-update | head -n 20 | tee updates.log

# 19. Cuentas bloqueadas/inactivas
echo -e "\n${BLUE}[19] Estado de cuentas:${NC}"
passwd -Sa | tee cuentas.log

# 20. Integridad de archivos (RPM)
echo -e "\n${BLUE}[20] Archivos modificados (RPM Verify):${NC}"
rpm -Va | head -n 20 | tee integridad.log

# 21. Interfaces de red
echo -e "\n${BLUE}[21] Interfaces de red:${NC}"
ip -brief addr | tee redes.log

# 22. Configuración DNS
echo -e "\n${BLUE}[22] Configuración DNS:${NC}"
cat /etc/resolv.conf | tee dns.log

# 23. Variables de entorno sensibles
echo -e "\n${BLUE}[23] Variables de entorno sensibles:${NC}"
env | grep -i "pass\|key\|secret" | tee variables.log

# 24. Historial de comandos root
echo -e "\n${BLUE}[24] Últimos comandos root:${NC}"
tail -n 20 /root/.bash_history | tee root_history.log

# 25. Verificar arranque y Secure Boot
echo -e "\n${BLUE}[25] Estado de arranque y Secure Boot:${NC}"
if [ -d /sys/firmware/efi ]; then
    echo -e "${GREEN}Modo de arranque:${NC} UEFI"
    SECUREBOOT_PATH=$(ls /sys/firmware/efi/vars/SecureBoot-* 2>/dev/null | head -n 1)
    if [ -f "$SECUREBOOT_PATH/data" ]; then
        STATUS=$(od -An -t u1 "$SECUREBOOT_PATH/data" | awk '{print $1}')
        if [ "$STATUS" -eq 1 ]; then
            echo -e "${GREEN}Secure Boot: HABILITADO ✅${NC}"
        else
            echo -e "${RED}Secure Boot: DESHABILITADO ❌${NC}"
        fi
    else
        echo -e "${YELLOW}Secure Boot: No se pudo determinar (variable no encontrada).${NC}"
    fi
else
    echo -e "${RED}Modo de arranque:${NC} BIOS Legacy"
    echo -e "${RED}Secure Boot: No disponible en BIOS Legacy.${NC}"
fi

echo -e "\n${BLUE}==================== FIN DE AUDITORÍA ====================${NC}"
