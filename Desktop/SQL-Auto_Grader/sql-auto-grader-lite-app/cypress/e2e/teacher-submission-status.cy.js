describe('Teacher Submission Status Page', () => {
  beforeEach(() => {
    cy.loginAsTeacher();
    cy.visit('/dashboard/submissionstatus');
  });

  it('loads submission status page', () => {
    cy.url().should('include', '/dashboard/submissionstatus');
    cy.contains('Submission Status').should('be.visible');
  });

  it('shows Assignments and Quizzes tabs', () => {
    cy.contains('.react-tabs__tab', 'Assignments').should('be.visible');
    cy.contains('.react-tabs__tab', 'Quizzes').should('be.visible');
  });

  it('Assignments tab is active by default', () => {
    cy.contains('.react-tabs__tab--selected', 'Assignments');
  });

  it('switches to Quizzes tab', () => {
    cy.contains('.react-tabs__tab', 'Quizzes').click();
    cy.contains('.react-tabs__tab--selected', 'Quizzes');
  });
});
