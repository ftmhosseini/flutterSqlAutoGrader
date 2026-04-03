describe('Login Page', () => {
  beforeEach(() => cy.visit('/login'));

  it('renders login form', () => {
    cy.get('input[type="email"]').should('be.visible');
    cy.get('input[type="password"]').should('be.visible');
    cy.get('button[type="submit"]').should('contain', 'Login');
  });

  it('shows error on wrong credentials', () => {
    cy.get('input[type="email"]').type('wrong@test.com');
    cy.get('input[type="password"]').type('wrongpassword');
    cy.get('button[type="submit"]').click();
    cy.contains('Wrong email or password').should('be.visible');
  });

  it('navigates to register page', () => {
    cy.contains('Sign Up').click();
    cy.url().should('include', '/register');
  });

  it('logs in as student and redirects to dashboard', () => {
    cy.get('input[type="email"]').type(Cypress.env('STUDENT_EMAIL'));
    cy.get('input[type="password"]').type(Cypress.env('STUDENT_PASSWORD'));
    cy.get('button[type="submit"]').click();
    cy.url().should('include', '/dashboard');
  });
});
