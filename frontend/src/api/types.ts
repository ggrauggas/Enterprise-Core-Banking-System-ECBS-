export interface Customer {
  customerId: number;
  firstName: string;
  lastName: string;
  birthDate: string;
  email: string;
  phone: string;
  status: 'ACTIVE' | 'INACTIVE' | 'DELETED';
  createdAt?: string;
  updatedAt?: string;
}

export interface Account {
  accountId: number;
  iban: string;
  customerId: number;
  balance: number;
  accountType: 'CHECKING' | 'SAVINGS';
  status: 'ACTIVE' | 'CLOSED';
  createdAt?: string;
}

export interface Transaction {
  transactionId: number;
  accountId: number;
  transactionType: string;
  amount: number;
  timestamp: string;
  description?: string;
  relatedAccountId?: number | null;
}

export interface CardEntity {
  cardId: number;
  accountId: number;
  cardNumber: string;
  creditLimit: number;
  availableCredit: number;
  status: 'ACTIVE' | 'BLOCKED' | 'CANCELLED';
}

export interface Loan {
  loanId: number;
  customerId: number;
  amount: number;
  interestRate: number;
  durationMonths: number;
  status: 'REQUESTED' | 'APPROVED' | 'REJECTED' | 'ACTIVE' | 'PAID' | 'DEFAULTED';
}

export interface BankReport {
  totalCustomers: number;
  activeCustomers: number;
  totalAccounts: number;
  totalDeposits: number;
  activeLoans: number;
  totalLoanAmount: number;
  activeCards: number;
}

export interface ScheduleRow {
  month: number;
  dueDate: string;
  payment: number;
  interest: number;
  principal: number;
  remaining: number;
}

export interface Simulation {
  amount: number;
  interestRate: number;
  durationMonths: number;
  monthlyPayment: number;
  totalPaid: number;
  totalInterest: number;
  schedule: ScheduleRow[];
}

export interface AuditEntry {
  auditId: number;
  username: string;
  eventTime: string;
  operation: string;
  entityType: string;
  entityId: number;
  oldValue: unknown;
  newValue: unknown;
}

export interface AuditStats {
  totalEntries: number;
  distinctUsers: number;
  firstEvent: string;
  lastEvent: string;
  byEntity: { name: string; count: number }[];
  byOperation: { name: string; count: number }[];
}
