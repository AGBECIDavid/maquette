import { Shell } from "../../../components/Shell.jsx";
import { EmployeeSpace } from "../../../screens/Employee.jsx";

export const metadata = { title: "Payer" };

export default function Page() {
  return <Shell><EmployeeSpace section="payer" /></Shell>;
}
