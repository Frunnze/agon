#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Departure {
    OthersStillWorking,
    LastOut,
}

#[derive(Debug, Default)]
pub struct WorkingSteps {
    working_count: usize,
    uncommitted_step_subjects: Vec<String>,
}

impl WorkingSteps {
    pub fn enter(&mut self) {
        self.working_count += 1;
    }

    pub fn leave(&mut self) -> Departure {
        self.working_count -= 1;
        if self.working_count == 0 {
            return Departure::LastOut;
        }
        Departure::OthersStillWorking
    }

    pub fn leave_with_changes(&mut self, step_subject: String) -> Departure {
        self.uncommitted_step_subjects.push(step_subject);
        self.leave()
    }

    pub fn take_uncommitted_step_subjects(&mut self) -> Vec<String> {
        std::mem::take(&mut self.uncommitted_step_subjects)
    }
}
