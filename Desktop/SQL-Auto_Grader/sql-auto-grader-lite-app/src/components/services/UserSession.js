class UserSession {
  constructor() {
    this._user = null;
  }

  set(data) {
    this._user = data; // { uid, email, fullName, role, createdAt }
  }

  get() {
    return this._user;
  }

  clear() {
    this._user = null;
  }

  get uid()      { return this._user?.uid; }
  get email()    { return this._user?.email; }
  get fullName() { return this._user?.fullName; }
  get role()     { return this._user?.role; }
  get createdAt(){ return this._user?.createdAt; }
}

const userSession = new UserSession();
export default userSession;
