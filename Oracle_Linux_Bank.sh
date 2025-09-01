#!/bin/bash
# Auditoría básica de un servidor Oracle Linux
# Autor: ChatGPT - versión extendida con detalle de usuarios

OUTPUT="reporte_auditoria_linux.txt"
> $OUTPUT

echo "========================================" | tee -a $OUTPUT
echo "   REPORTE DE AUDITORÍA - ORACLE LINUX  " | tee -a $OUTPUT
echo " Generado el: $(date)" | tee -a $OUTPUT
echo "========================================" | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

#############################################
# 1. Versión del Servidor
#############################################
echo ">>> Versión del Servidor" | tee -a $OUTPUT
cat /etc/*release | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

#############################################
# 2. Servicios Activos
#############################################
echo ">>> Servicios Activos" | tee -a $OUTPUT
systemctl list-units --type=service --state=running | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

#############################################
# 3. Puertos Abiertos
#############################################
echo ">>> Puertos Abiertos" | tee -a $OUTPUT
ss -tulnp | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

#############################################
# 4. Usuarios Locales y Detalle
#############################################
echo ">>> Usuarios Locales y su Detalle" | tee -a $OUTPUT
echo "----------------------------------------" | tee -a $OUTPUT

for user in $(cut -d: -f1 /etc/passwd); do
    STATUS=$(passwd -S $user 2>/dev/null | awk '{print $2}')
    case $STATUS in
        P) USER_STATUS="Activo (Password válido)" ;;
        L) USER_STATUS="Bloqueado" ;;
        NP) USER_STATUS="Sin contraseña" ;;
        *) USER_STATUS="Desconocido" ;;
    esac
    
    echo "Usuario: $user" | tee -a $OUTPUT
    echo "Estado: $USER_STATUS" | tee -a $OUTPUT
    echo "---- Detalle de contraseñas y expiración ----" | tee -a $OUTPUT
    chage -l $user 2>/dev/null | tee -a $OUTPUT
    echo "----------------------------------------" | tee -a $OUTPUT
done
echo "" | tee -a $OUTPUT

#############################################
# 5. Usuarios con privilegios de sudo
#############################################
echo ">>> Usuarios con privilegios de SUDO" | tee -a $OUTPUT
getent group wheel | awk -F: '{print $4}' | tr ',' '\n' | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

#############################################
# 6. Carpetas con permisos 777
#############################################
echo ">>> Carpetas con permisos 777" | tee -a $OUTPUT
find / -type d -perm 777 2>/dev/null | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

#############################################
# 7. Configuración de Firewall
#############################################
echo ">>> Reglas de Firewall (iptables / firewalld)" | tee -a $OUTPUT
iptables -L -n -v 2>/dev/null | tee -a $OUTPUT
firewall-cmd --list-all 2>/dev/null | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

#############################################
# 8. Logs de Auditoría
#############################################
echo ">>> Estado de los logs de auditoría" | tee -a $OUTPUT
systemctl status auditd | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

#############################################
# 9. Espacio en Disco
#############################################
echo ">>> Espacio en Disco" | tee -a $OUTPUT
df -h | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

#############################################
# 10. Memoria y SWAP
#############################################
echo ">>> Uso de Memoria y Swap" | tee -a $OUTPUT
free -h | tee -a $OUTPUT
swapon --show | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

#############################################
# 11. Actualizaciones pendientes
#############################################
echo ">>> Actualizaciones pendientes del SO" | tee -a $OUTPUT
dnf check-update 2>/dev/null | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

echo "========================================" | tee -a $OUTPUT
echo "   FIN DEL REPORTE DE AUDITORÍA          " | tee -a $OUTPUT
echo "========================================" | tee -a $OUTPUT
