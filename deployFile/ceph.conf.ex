mon_osd_down_out_interval = 900
mon_osd_min_down_reporters = 6

[osd]
filestore_journal_writeahead = True
osd_max_backfills = 2
osd_recovery_max_chunk = 32M
osd_heartbeat_interval = 60
osd_backfill_scan_min = 16
osd_recovery_max_active = 1
filestore_op_threads = 4
filestore_xattr_use_omap = False
osd_recovery_threads = 1
osd_backfill_scan_max = 256
journal_queue_max_bytes = 32M
journal_max_write_bytes = 32M
osd_heartbeat_grace = 100
osd_heartbeat_use_min_delay_socket = True
