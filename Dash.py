import pandas as pd
import numpy as np
import re
import sys

with open(sys.argv[1]) as origin_file:
    for linea in origin_file:
        name = 'Reporte estado'
        namestr = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if name in linea:
                    namestr.append(linea)
        version = 'VERSION:'
        versionstr = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if version in linea:
                    versionstr.append(linea)
        memoria = 'Memoria RAM/SWAP:'
        memoriastr = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if memoria in linea:
                    memoriastr.append(linea)
        cpu = 'CPU:'
        cpustr = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if cpu in linea:
                    cpustr.append(linea)
        filesystem = 'Filesystems previos montados'
        filesystemstr = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if filesystem in linea:
                    filesystemstr.append(linea)
        configuracion_ip = 'Configuracion IP:'
        configuracion_ipstr = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if configuracion_ip in linea:
                    configuracion_ipstr.append(linea)
        estado_de_rutas = 'Estado de Rutas:'
        estado_de_rutasstr = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if estado_de_rutas in linea:
                    estado_de_rutasstr.append(linea)

with open(sys.argv[1]) as origin_file:
    for linea in origin_file:
        memoria_fail = 'ATENCION - DIFERENCIA EN MEMORIA'
        memoriastr_fail = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if memoria_fail in linea:
                    memoriastr_fail.append(linea)
        cpu_fail = 'ATENCION - DIFERENCIA EN CPU'
        cpustr_fail = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if cpu_fail in linea:
                    cpustr_fail.append(linea)
        filesystem_fail = 'DIFERENCIA CON FS MONTADOS'
        filesystemstr_fail = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if filesystem_fail in linea:
                    filesystemstr_fail.append(linea)
        configuracion_ip_fail = 'ATENCION - DIFERENCIAS CON PLACAS/IPS'
        configuracion_ipstr_fail = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if configuracion_ip_fail in linea:
                    configuracion_ipstr_fail.append(linea)
        estado_de_rutas_fail = 'Faltan las siguientes rutas'
        estado_de_rutasstr_fail = []
        with open(sys.argv[1]) as lineas:
            for linea in lineas:
                if estado_de_rutas_fail in linea:
                    estado_de_rutasstr_fail.append(linea)

versionstr = "".join(versionstr)
versionstr = versionstr.split("\t")[1].split("\n")[0]
namestr = "".join(namestr)
namestr = namestr.split("\n")[0]


memoriastr = "".join(memoriastr)
memoriastr = memoriastr.split("\n")[0]
cpustr = "".join(cpustr)
cpustr = cpustr.split("\n")[0]
filesystemstr = "".join(filesystemstr)
filesystemstr = filesystemstr.split("\n")[0]
configuracion_ipstr = "".join(configuracion_ipstr)
configuracion_ipstr = configuracion_ipstr.split("\n")[0]
estado_de_rutasstr = "".join(estado_de_rutasstr)
estado_de_rutasstr = estado_de_rutasstr.split("\n")[0]


memoriastr_fail = "".join(memoriastr_fail)
memoriastr_fail = memoriastr_fail.split("\n")[0]
cpustr_fail = "".join(cpustr_fail)
cpustr_fail = cpustr_fail.split("\n")[0]
filesystemstr_fail = "".join(filesystemstr_fail)
filesystemstr_fail = filesystemstr_fail.split("\n")[0]
configuracion_ipstr_fail = "".join(configuracion_ipstr_fail)
configuracion_ipstr_fail = configuracion_ipstr_fail.split("\n")[0]
estado_de_rutasstr_fail = "".join(estado_de_rutasstr_fail)
estado_de_rutasstr_fail = estado_de_rutasstr_fail.split("\n")[0]


with open(sys.argv[1]) as origin_file:
    for linea in origin_file:
        if memoriastr in linea:
            memoriastr = memoriastr.replace('Memoria RAM/SWAP: OK', '0')
        if memoriastr_fail in linea:
            memoriastr_fail = memoriastr_fail.replace('#### ATENCION - DIFERENCIA EN MEMORIA ####', '1')
with open(sys.argv[1]) as origin_file:
    for linea in origin_file:
        if cpustr in linea:
            cpustr = cpustr.replace('CPU: OK', '0')
        if cpustr_fail in linea:
            cpustr_fail = cpustr_fail.replace('#### ATENCION - DIFERENCIA EN CPU ####', '1')
filesystemnew = "0"
with open(sys.argv[1]) as origin_file:
    for linea in origin_file:
        if filesystemstr in linea:
            filesystemstr = filesystemnew
        if filesystemstr_fail in linea:
            filesystemstr_fail = filesystemstr_fail.replace("#### ATENCION - DIFERENCIA CON FS MONTADOS ####", "1")
with open(sys.argv[1]) as origin_file:
    for linea in origin_file:
        if configuracion_ipstr in linea:
            configuracion_ipstr = configuracion_ipstr.replace('Configuracion IP: OK', '0')
        if configuracion_ipstr_fail in linea:
            configuracion_ipstr_fail = configuracion_ipstr_fail.replace('#### ATENCION - DIFERENCIAS CON PLACAS/IPS ####', '1')
with open(sys.argv[1]) as origin_file:
    for linea in origin_file:
        if estado_de_rutasstr in linea:
            estado_de_rutasstr = estado_de_rutasstr.replace("Estado de Rutas: OK", '0')
        if estado_de_rutasstr_fail in linea:
            estado_de_rutasstr_fail = estado_de_rutasstr_fail.replace("Faltan las siguientes rutas", '1')
print(namestr)
print(versionstr)
print(memoriastr)
print(memoriastr_fail)
print(cpustr)
print(cpustr_fail)
print(filesystemstr)
print(filesystemstr_fail)
print(configuracion_ipstr)
print(configuracion_ipstr_fail)
print(estado_de_rutasstr)
print(estado_de_rutasstr_fail)

#como generar un http request postzz
