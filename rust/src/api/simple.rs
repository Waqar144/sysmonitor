use sysinfo::System;

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Helloasd, {name}!")
}

pub struct MySystem {
    sys: System,
}

pub struct MyProcess {
    pub pid: usize,
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
                pid: p.1.pid().into(),
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
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
