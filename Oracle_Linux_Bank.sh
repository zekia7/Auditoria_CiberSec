#!/bin/bash
# Auditoría básica de Oracle Linux
# Autor: ChatGPT

echo "======================================="
echo "   AUDITORÍA DE SERVIDOR ORACLE LINUX"
echo "======================================="

# Función para separar secciones
separador() {
    echo "---------------------------------------"
}

# 1. Versión del servidor
separador
echo "[1] Versión del Servidor"
cat /etc/os-release | grep -E "NAME=|VERSION="

# 2. Servicios activos
separador
echo "[2] Servicios Activos"
systemctl list-units --type=service --state=running

# 3. Puertos abiertos
separador
echo "[3] Puertos Abiertos"
ss -tuln

# 4. Espacio en disco
separador
echo "[4] Uso de Disco"
df -hT

# 5. Rendimiento de memoria y swap
separador
echo "[5] Memoria y Swap"
free -h

# 6. Usuarios locales
separador
echo "[6] Usuarios Locales"
cut -d: -f1 /etc/passwd

# 7. Usuarios activos/inactivos
separador
echo "[7] Estado de Usuarios"
while IFS=: read -r user _ uid gid _ home shell; do
    if [[ "$shell" == "/sbin/nologin" || "$shell" == "/bin/false" ]]; then
        echo "Usuario: $user --> INACTIVO (shell: $shell)"
    else
        echo "Usuario: $user --> ACTIVO (shell: $shell)"
    fi
done < /etc/passwd

# 8. Usuarios con privilegios sudo
separador
echo "[8] Usuarios con Privilegios SUDO"
getent group wheel

# 9. Grupos y usuarios dentro de cada grupo
separador
echo "[9] Grupos y Miembros"
getent group | awk -F: '{print "Grupo: "$1 " -> " $4}'

# 10. Carpetas con permisos 777
separador
echo "[10] Carpetas con permisos 777 (puede tardar)"
find / -type d -perm 0777 2>/dev/null

# 11. Firewall (iptables + firewalld)
separador
echo "[11] Configuración de Firewall"
if command -v firewall-cmd &> /dev/null; then
    echo "Firewalld:"
    firewall-cmd --list-all
fi
echo "Iptables:"
iptables -L -n -v

# 12. Actualizaciones pendientes
separador
echo "[12] Actualizaciones Pendientes"
dnf check-update || yum check-update

# 13. Logs de auditoría
separador
echo "[13] Estado de Auditoría (auditd)"
systemctl status auditd | grep Active

# 14. Parámetros globales de contraseña
separador
echo "[14] Políticas de Contraseña (globales)"
grep -E "PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE" /etc/login.defs

# 15. Políticas de contraseña por usuario
separador
echo "[15] Políticas de Contraseña por Usuario"
chage -l root
for user in $(cut -d: -f1 /etc/passwd); do
    chage -l "$user" 2>/dev/null | grep "Maximum" && echo "Usuario: $user"
done

# 16. Usuarios genéricos / default
separador
echo "[16] Usuarios Genéricos/Default"
grep -E "^(root|bin|daemon|adm|lp|sync|shutdown|halt|mail|uucp|operator|games|nobody)" /etc/passwd

# 17. SELinux o AppArmor
separador
echo "[17] Estado de SELinux/AppArmor"
getenforce 2>/dev/null || echo "SELinux no disponible"
if command -v aa-status &> /dev/null; then
    aa-status
else
    echo "AppArmor no instalado"
fi

# 18. Integridad de binarios críticos
separador
echo "[18] Verificación de Integridad de Binarios Críticos"
for bin in /bin/ls /bin/bash /usr/bin/sudo; do
    if [ -f "$bin" ]; then
        sha256sum "$bin"
    fi
done

separador
echo ">>> Auditoría finalizada."
