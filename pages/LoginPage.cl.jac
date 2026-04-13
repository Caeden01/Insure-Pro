import from "@jac/runtime" { useNavigate, jacLogin, jacSignup }

def:pub page() -> JsxElement {
    has is_login: bool = True;
    has username: str = "";
    has password: str = "";
    has error: str = "";
    has loading: bool = False;
    # Signup profile fields
    has full_name: str = "";
    has address: str = "";
    has city: str = "";
    has state: str = "";
    has zip_code: str = "";
    has phone: str = "";
    has email: str = "";
    has dob: str = "";
    has insurance_company: str = "";
    has member_id: str = "";
    has plan_type: str = "";
    has group_number: str = "";

    navigate = useNavigate();

    async def handle_submit(e: any) -> None {
        e.preventDefault();
        loading = True;
        error = "";
        try {
            if is_login {
                login_res = await jacLogin(username, password);
                if login_res {
                    navigate("/dashboard");
                } else {
                    error = "Invalid username or password";
                }
            } else {
                # Validate required fields
                if not full_name or not email or not insurance_company or not member_id {
                    error = "Please fill in all required fields.";
                    loading = False;
                    return;
                }
                signup_res = await jacSignup(username, password);
                if signup_res {
                    # Save profile info to localStorage
                    profile = JSON.stringify({
                        "full_name": full_name,
                        "address": address,
                        "city": city,
                        "state": state,
                        "zip_code": zip_code,
                        "phone": phone,
                        "email": email,
                        "dob": dob,
                        "insurance_company": insurance_company,
                        "member_id": member_id,
                        "plan_type": plan_type,
                        "group_number": group_number
                    });
                    window.localStorage.setItem("insure_pro_profile", profile);
                    login_after_signup = await jacLogin(username, password);
                    if login_after_signup {
                        navigate("/dashboard");
                    } else {
                        error = "Account created — please sign in";
                    }
                } else {
                    error = "Signup failed. Username may already be taken.";
                }
            }
        } except Exception as e {
            error = "Authentication error. Please try again.";
        }
        loading = False;
    }

    def handle_username(e: any) -> None { username = e.target.value; }
    def handle_password(e: any) -> None { password = e.target.value; }
    def handle_full_name(e: any) -> None { full_name = e.target.value; }
    def handle_address(e: any) -> None { address = e.target.value; }
    def handle_city(e: any) -> None { city = e.target.value; }
    def handle_state(e: any) -> None { state = e.target.value; }
    def handle_zip(e: any) -> None { zip_code = e.target.value; }
    def handle_phone(e: any) -> None { phone = e.target.value; }
    def handle_email(e: any) -> None { email = e.target.value; }
    def handle_dob(e: any) -> None { dob = e.target.value; }
    def handle_insurance(e: any) -> None { insurance_company = e.target.value; }
    def handle_member_id(e: any) -> None { member_id = e.target.value; }
    def handle_plan_type(e: any) -> None { plan_type = e.target.value; }
    def handle_group_number(e: any) -> None { group_number = e.target.value; }

    def toggle_mode() -> None {
        is_login = not is_login;
        error = "";
    }

    return (
        <div className="auth-page">
            <div className="auth-container" style={{"maxWidth": is_login and "26rem" or "32rem"}}>
                <div className="auth-header">
                    <h1>{is_login and "Welcome to InsurePro" or "Create Your Account"}</h1>
                    <p>{is_login and "Sign in to investigate insurance denials" or "We need some info to personalize your appeal letters"}</p>
                </div>
                <div className="auth-card">
                    {error and (
                        <div className="error-box mb-5">
                            {error}
                        </div>
                    )}
                    <form onSubmit={handle_submit} className="auth-form">
                        <div>
                            <label className="label">Username</label>
                            <input className="input" type="text" value={username} onChange={handle_username}
                                   placeholder="Choose a username" required={True} autoComplete="username" />
                        </div>
                        <div>
                            <label className="label">Password</label>
                            <input className="input" type="password" value={password} onChange={handle_password}
                                   placeholder="••••••••" required={True} autoComplete="current-password" />
                        </div>

                        {not is_login and (
                            <div style={{"display": "flex", "flexDirection": "column", "gap": "0.75rem", "borderTop": "1px solid var(--color-border)", "paddingTop": "1rem", "marginTop": "0.5rem"}}>
                                <p className="text-xs text-muted-foreground" style={{"marginBottom": "0.25rem"}}>{"This information will be used to fill in your appeal letters automatically."}</p>

                                <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "0.75rem"}}>
                                    <div>
                                        <label className="label">Full Name *</label>
                                        <input className="input" type="text" value={full_name} onChange={handle_full_name}
                                               placeholder="John Doe" required={True} />
                                    </div>
                                    <div>
                                        <label className="label">Date of Birth</label>
                                        <input className="input" type="date" value={dob} onChange={handle_dob} />
                                    </div>
                                </div>

                                <div>
                                    <label className="label">Street Address</label>
                                    <input className="input" type="text" value={address} onChange={handle_address}
                                           placeholder="123 Main Street" />
                                </div>

                                <div style={{"display": "grid", "gridTemplateColumns": "2fr 1fr 1fr", "gap": "0.75rem"}}>
                                    <div>
                                        <label className="label">City</label>
                                        <input className="input" type="text" value={city} onChange={handle_city}
                                               placeholder="Anytown" />
                                    </div>
                                    <div>
                                        <label className="label">State</label>
                                        <input className="input" type="text" value={state} onChange={handle_state}
                                               placeholder="CA" />
                                    </div>
                                    <div>
                                        <label className="label">Zip Code</label>
                                        <input className="input" type="text" value={zip_code} onChange={handle_zip}
                                               placeholder="90210" />
                                    </div>
                                </div>

                                <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "0.75rem"}}>
                                    <div>
                                        <label className="label">Phone</label>
                                        <input className="input" type="tel" value={phone} onChange={handle_phone}
                                               placeholder="(555) 123-4567" />
                                    </div>
                                    <div>
                                        <label className="label">Email *</label>
                                        <input className="input" type="email" value={email} onChange={handle_email}
                                               placeholder="john@email.com" required={True} />
                                    </div>
                                </div>

                                <div style={{"borderTop": "1px solid var(--color-border)", "paddingTop": "0.75rem", "marginTop": "0.25rem"}}>
                                    <p className="text-xs text-muted-foreground" style={{"marginBottom": "0.5rem"}}>{"Insurance Information"}</p>
                                </div>

                                <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "0.75rem"}}>
                                    <div>
                                        <label className="label">Insurance Company *</label>
                                        <input className="input" type="text" value={insurance_company} onChange={handle_insurance}
                                               placeholder="Blue Cross Blue Shield" required={True} />
                                    </div>
                                    <div>
                                        <label className="label">Member ID *</label>
                                        <input className="input" type="text" value={member_id} onChange={handle_member_id}
                                               placeholder="XYZ123456789" required={True} />
                                    </div>
                                </div>

                                <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "0.75rem"}}>
                                    <div>
                                        <label className="label">Plan Type</label>
                                        <input className="input" type="text" value={plan_type} onChange={handle_plan_type}
                                               placeholder="PPO, HMO, EPO, etc." />
                                    </div>
                                    <div>
                                        <label className="label">Group Number</label>
                                        <input className="input" type="text" value={group_number} onChange={handle_group_number}
                                               placeholder="GRP-001234" />
                                    </div>
                                </div>
                            </div>
                        )}

                        <button className="btn btn-primary w-full h-12 mt-1" type="submit" disabled={loading}>
                            {(
                                ("Signing in..." if is_login else "Creating account...")
                                if loading
                                else ("Sign in" if is_login else "Create Account")
                            )}
                        </button>
                    </form>
                    <div className="auth-toggle">
                        {"Don't have an account? " if is_login else "Already have an account? "}
                        <button type="button" className="toggle-btn" onClick={toggle_mode}>
                            {"Sign up" if is_login else "Sign in"}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
