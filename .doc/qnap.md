# QNAP Hooks (`modules/qnap/qnapmaster.sh`)

Lichtgewicht module die standaard alleen laadt wanneer `OS_TYPE == "QNAP"` (of via `./master --all`).

### Functies
- `containers`: Toont actieve en gestopte containers via `docker` of `system-docker`.
- `cleanup`: Scant `/share` op `@Recycle` en `.@__thumb` en biedt interactieve opschoning.
- `entware`: Voert `opkg update && opkg upgrade` uit.

### Gebruik
```bash
./master qnap containers
./master qnap cleanup
./master qnap entware
```
