use sysinfo::{Networks, Pid, System};

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Helloasd, {name}!")
}

pub struct MySystem {
    sys: System,
    net: Networks,
}

pub struct MyProcess {
    pub pid: u32,
    pub name: String,
    pub cpu_usage: f32,
    pub memory_usage: u64,
}

pub struct ProcessDetails {
    pub cmd: String,
    pub virtual_memory: u64,
    pub disk_read: u64,
    pub disk_write: u64,
    pub cwd: String,
    pub env: Vec<String>,
}

pub enum SortBy {
    PID,
    Name,
    CPU,
    Memory,
}

pub enum SortOrder {
    Asc,
    Desc,
}

pub enum Signal {
    Terminate,
    Kill,
    Hangup,
    Continue,
    Stop,
    Interrupt,
}

impl MySystem {
    pub fn new_all() -> MySystem {
        MySystem {
            sys: System::new_all(),
            net: Networks::new_with_refreshed_list(),
        }
    }

    pub fn processes(&mut self, sorting: SortBy, sort_order: SortOrder) -> Vec<MyProcess> {
        self.sys.refresh_processes_specifics(
            sysinfo::ProcessesToUpdate::All,
            sysinfo::ProcessRefreshKind::new().with_cpu().with_memory(),
        );
        let processes = self.sys.processes();
        let mut ret = Vec::new();
        for (_, p) in processes {
            match p.thread_kind() {
                Some(sysinfo::ThreadKind::Kernel) => continue,
                Some(sysinfo::ThreadKind::Userland) => continue,
                None => (),
            };

            ret.push(MyProcess {
                pid: p.pid().as_u32(),
                name: p.name().to_str().unwrap().to_string(),
                cpu_usage: p.cpu_usage() / self.sys.cpus().len() as f32,
                memory_usage: p.memory(),
            });
        }

        match (sorting, sort_order) {
            (SortBy::PID, SortOrder::Asc) => ret.sort_by(|l, r| l.pid.cmp(&r.pid)),
            (SortBy::PID, SortOrder::Desc) => ret.sort_by(|l, r| r.pid.cmp(&l.pid)),
            (SortBy::Name, SortOrder::Asc) => ret.sort_by(|l, r| l.name.cmp(&r.name)),
            (SortBy::Name, SortOrder::Desc) => ret.sort_by(|l, r| r.name.cmp(&l.name)),
            (SortBy::CPU, SortOrder::Asc) => {
                ret.sort_by(|l, r| l.cpu_usage.partial_cmp(&r.cpu_usage).unwrap())
            }
            (SortBy::CPU, SortOrder::Desc) => {
                ret.sort_by(|l, r| r.cpu_usage.partial_cmp(&l.cpu_usage).unwrap())
            }
            (SortBy::Memory, SortOrder::Asc) => {
                ret.sort_by(|l, r| r.memory_usage.cmp(&l.memory_usage))
            }
            (SortBy::Memory, SortOrder::Desc) => {
                ret.sort_by(|l, r| l.memory_usage.cmp(&r.memory_usage))
            }
        }
        ret
    }

    pub fn memory_usage(&mut self) -> (u64, u64) {
        self.sys
            .refresh_memory_specifics(sysinfo::MemoryRefreshKind::new().with_ram());
        (self.sys.total_memory(), self.sys.used_memory())
    }

    pub fn network_usage(&mut self) -> (u64, u64) {
        self.net.refresh();
        let mut rx = 0;
        let mut tx = 0;
        for iface in &self.net {
            rx += iface.1.received();
            tx += iface.1.transmitted();
        }
        (rx, tx)
    }

    pub fn send_signal(&self, pid: u32, signal: Signal) -> bool {
        self.sys
            .process(Pid::from_u32(pid))
            .and_then(|p| match signal {
                Signal::Terminate => p.kill_with(sysinfo::Signal::Term),
                Signal::Kill => p.kill_with(sysinfo::Signal::Kill),
                Signal::Hangup => p.kill_with(sysinfo::Signal::Hangup),
                Signal::Continue => p.kill_with(sysinfo::Signal::Continue),
                Signal::Stop => p.kill_with(sysinfo::Signal::Stop),
                Signal::Interrupt => p.kill_with(sysinfo::Signal::Interrupt),
            })
            .unwrap_or(false)
    }

    pub fn process_details(&self, pid: u32) -> Option<ProcessDetails> {
        let Some(p) = self.sys.process(Pid::from_u32(pid)) else {
            return None;
        };
        let cmd = p
            .cmd()
            .join(&std::ffi::OsString::from(" "))
            .to_str()
            .unwrap()
            .to_string();
        let disk_read = p.disk_usage().total_read_bytes;
        let disk_write = p.disk_usage().total_written_bytes;

        let env: Vec<String> = p
            .environ()
            .iter()
            .map(|e| e.as_os_str().to_str().unwrap().to_string())
            .collect();
        let cwd = p
            .cwd()
            .map(|p| p.to_str().unwrap().to_string())
            .unwrap_or_default();
        let virtual_memory = p.virtual_memory();

        Some(ProcessDetails {
            cmd,
            disk_read,
            disk_write,
            virtual_memory,
            cwd,
            env,
        })
    }

    pub fn parent_pid(&self, pid: u32) -> Option<u32> {
        self.sys
            .process(Pid::from_u32(pid))
            .and_then(|p| p.parent())
            .map(|parent_pid| parent_pid.as_u32())
    }
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
