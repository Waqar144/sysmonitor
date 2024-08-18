use sysinfo::{Pid, System};

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Helloasd, {name}!")
}

pub struct MySystem {
    sys: System,
}

pub struct MyProcess {
    pub pid: u32,
    pub name: String,
    pub cpu_usage: f32,
    pub memory_usage: u64,
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
        }
    }

    pub fn processes(&mut self, sorting: SortBy, sort_order: SortOrder) -> Vec<MyProcess> {
        self.sys.refresh_processes_specifics(
            sysinfo::ProcessesToUpdate::All,
            sysinfo::ProcessRefreshKind::new().with_cpu().with_memory(),
        );
        let processes = self.sys.processes();
        let mut ret = Vec::new();
        for p in processes {
            match p.1.thread_kind() {
                Some(sysinfo::ThreadKind::Kernel) => continue,
                Some(sysinfo::ThreadKind::Userland) => continue,
                None => (),
            };

            ret.push(MyProcess {
                pid: p.1.pid().as_u32(),
                name: p.1.name().to_str().unwrap().to_string(),
                cpu_usage: p.1.cpu_usage() / self.sys.cpus().len() as f32,
                memory_usage: p.1.memory(),
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
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
