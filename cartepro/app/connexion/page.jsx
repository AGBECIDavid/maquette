import { Shell } from "../../components/Shell.jsx";
import { Login } from "../../screens/Auth.jsx";

export const metadata = { title: "Connexion" };

export default function Page() {
  return <Shell><Login /></Shell>;
}
